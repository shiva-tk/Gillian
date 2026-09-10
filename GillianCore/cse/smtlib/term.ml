open Extraction_utils

type t =
  | Var of string
  | App of (Sexplib.Sexp.t * t list)
  | Fun of (string * Sort.t * t)
  | Exists of (string * Sort.t * t)
  | Forall of (string * Sort.t * t)
  | Let of ((string * t) list * t)
  | Match of (t * (Pattern.t * t) list)

let binder_seed = Utils.string_to_char_list "x"

let rec from_extracted (t : Extracted.term) : t =
  match t with
  | TFVar x ->
     Var (Utils.string_from_char_list x)
  | TBVar (_, _) ->
     failwith "Term.from_extracted: encountered a term that was not locally closed."
  | TApp (f, _s, ts) ->
     App
       (Utils.sexp_of_identifier f,
        (List.map from_extracted ts))
  | TFun (s, t) ->
     let s' = Sort.from_extracted s in
     let x = Extracted.fresh_string_of_set binder_seed (Extracted.fv t) in
     let t' = Extracted.term_open 0 [Extracted.TFVar x] t in
     Fun (Utils.string_from_char_list x, s', from_extracted t')
  | TExists (s, t) ->
     let s' = Sort.from_extracted s in
     let x = Extracted.fresh_string_of_set binder_seed (Extracted.fv t) in
     let t' = Extracted.term_open 0 [Extracted.TFVar x] t in
     Exists (Utils.string_from_char_list x, s', from_extracted t')
  | TForall (s, t) ->
     let s' = Sort.from_extracted s in
     let x = Extracted.fresh_string_of_set binder_seed (Extracted.fv t) in
     let t' = Extracted.term_open 0 [Extracted.TFVar x] t in
     Forall (Utils.string_from_char_list x, s', from_extracted t')
  | TLet (ts, t) ->
     let xs = Extracted.fresh_strings_of_set binder_seed (List.length ts) (Extracted.fv t) in
     let xts = List.map2 (fun x t -> (Utils.string_from_char_list x, from_extracted t)) xs ts in
     let t' = Extracted.term_open 0 (List.map (fun x -> Extracted.TFVar x) xs) t in
     Let (xts, from_extracted t')
  | TMatch (t, pts) ->
     let pts' =
       List.map
         (fun (p, t) ->
           let (xs, p') = match p with
             | Extracted.PVar ->
                let x = Extracted.fresh_string_of_set binder_seed (Extracted.fv t) in
                ([x], Pattern.Var (Utils.string_from_char_list x))
             | Extracted.PApp (c, n) ->
                let xs = Extracted.fresh_strings_of_set binder_seed n (Extracted.fv t) in
                (xs, Pattern.App (Utils.sexp_of_identifier c,
                                  List.map Utils.string_from_char_list xs))
          in
          let t' = Extracted.term_open 0 (List.map (fun x -> Extracted.TFVar x) xs) t in
          (p', from_extracted t'))
         pts
     in
     Match (from_extracted t, pts')

let sanitise_var =
  let pattern = Str.regexp "#" in
  Str.global_replace pattern "$$"

let rec to_sexp t =
  let open Sexplib in
  match t with
  | Var x -> Sexp.Atom (sanitise_var x)
  | App (f, ts) ->
    (* [List.is_empty] is OCaml 5.1; the project switch is 4.14. *)
    (match ts with
     | [] -> f
     | _ -> Sexp.List (f :: (List.map to_sexp ts)))
  | Fun (x, s, t) ->
     let binder = Sexp.List [Sexp.Atom (sanitise_var x); Sort.to_sexp s] in
     let binders = Sexp.List [binder] in
     Sexp.List [Sexp.Atom "lambda"; binders; to_sexp t]
  | Exists (x, s, t) ->
     let binder = Sexp.List [Sexp.Atom (sanitise_var x); Sort.to_sexp s] in
     let binders = Sexp.List [binder] in
     Sexp.List [Sexp.Atom "exists"; binders; to_sexp t]
  | Forall (x, s, t) ->
     let binder = Sexp.List [Sexp.Atom (sanitise_var x); Sort.to_sexp s] in
     let binders = Sexp.List [binder] in
     Sexp.List [Sexp.Atom "forall"; binders; to_sexp t]
  | Let (xts, t) ->
     let binder (x, t) = Sexp.List [Sexp.Atom (sanitise_var x); to_sexp t] in
     let binders = Sexp.List (List.map binder xts) in
     Sexp.List [Sexp.Atom "let"; binders; to_sexp t]
  | Match (t, pts) ->
     let case (p, t) = Sexp.List [Pattern.to_sexp p; to_sexp t] in
     let cases = Sexp.List (List.map case pts) in
     Sexp.List [Sexp.Atom "match"; to_sexp t; cases]
