open Syntax
open Extraction_utils

module type S = sig
  type exp
  type typ

  val decls : Sexplib.Sexp.t list
  val encode : (string, typ) Hashtbl.t -> exp list -> Sexplib.Sexp.t list option
end

module type Coerce = sig
  type exp
  type typ

  val coerce_symbexp : exp -> Symbexp.t option
  val coerce_type : typ -> Type.t option
end

module Make (C : Coerce) : S with type exp = C.exp and type typ = C.typ = struct
  type exp = C.exp
  type typ = C.typ

  let decls =
    let open Sexplib in
    let atom s = Sexp.Atom (Utils.string_from_char_list s) in
    [
      Sexp.List
        [
          Sexp.Atom "declare-datatype";
          atom Extracted.s_val;
          Sexp.List
            [
              Sexp.List [ atom Extracted.c_null_val ];
              Sexp.List
                [
                  atom Extracted.c_bool_val;
                  Sexp.List [ atom Extracted.g_bool_val; atom Extracted.s_bool ];
                ];
              Sexp.List
                [
                  atom Extracted.c_nat_val;
                  Sexp.List [ atom Extracted.g_nat_val; atom Extracted.s_int ];
                ];
              Sexp.List
                [
                  atom Extracted.c_rat_val;
                  Sexp.List [ atom Extracted.g_rat_val; atom Extracted.s_real ];
                ];
              Sexp.List
                [
                  atom Extracted.c_string_val;
                  Sexp.List
                    [ atom Extracted.g_string_val; atom Extracted.s_string ];
                ];
              Sexp.List
                [
                  atom Extracted.c_list_val;
                  Sexp.List
                    [
                      atom Extracted.g_list_val;
                      Sexp.List [ atom Extracted.s_seq; atom Extracted.s_val ];
                    ];
                ];
            ];
        ];
    ]

  let encode typingenv es : Sexplib.Sexp.t list option =
    (* Try and coerce types in type env,  *)
    let lst =
      Hashtbl.fold
        (fun x t acc ->
          match (C.coerce_type t, acc) with
          | Some t', Some acc' -> Some ((x, Type.to_extracted t') :: acc')
          | _, _ -> None)
        typingenv (Some [])
    in
    let typingenv' = Option.map Utils.list_to_gmap_string lst in

    (* Try and coerce expressions in query *)
    let es' =
      List.fold_right
        (fun e acc ->
          match (C.coerce_symbexp e, acc) with
          | Some e', Some acc' -> Some (Symbexp.to_extracted e' :: acc')
          | _, _ -> None)
        es (Some [])
    in

    let open Sexplib in
    let open Smtlib in
    (* If both coercions were successful, continue *)
    match (typingenv', es') with
    | Some typingenv', Some es' -> (
        let encs =
          List.fold_right
            (fun e acc ->
              let enc =
                Option.bind
                  (Extracted.encode_sexp typingenv' e)
                  Extracted.to_bool
              in
              match (enc, acc) with
              | Some enc', Some acc' -> Some (enc' :: acc')
              | _ -> None)
            es' (Some [])
        in
        match encs with
        | Some encs' ->
            let phis =
              List.concat
                (List.map
                   (fun ((t, _), phi) ->
                     t
                     :: Extracted.gset_elements Extracted.term_eq_decision
                          Extracted.term_countable phi)
                   encs')
            in
            let xss = List.map Extracted.fv phis in
            let xs =
              Extracted.union_list
                (Extracted.gset_empty Extracted.String.eq_dec
                   Extracted.String.countable)
                (Extracted.gset_union Extracted.String.eq_dec
                   Extracted.String.countable)
                xss
            in
            let xs =
              Extracted.gset_elements Extracted.String.eq_dec
                Extracted.String.countable xs
            in
            let xs = List.map Utils.string_from_char_list xs in
            let declare_const x =
              let t =
                Option.value ~default:Extracted.TVal
                  (Extracted.gmap_lookup Extracted.String.eq_dec
                     Extracted.String.countable
                     (Utils.string_to_char_list x)
                     typingenv')
              in
              let s = Extracted.encode_type t in
              Sexp.List
                [
                  Sexp.Atom "declare-const";
                  Sexp.Atom (Term.sanitise_var x);
                  Sort.to_sexp (Sort.from_extracted s);
                ]
            in
            let decls = List.map declare_const xs in
            let phis =
              List.map
                (fun t ->
                  Sexp.List
                    [ Sexp.Atom "assert"; Term.to_sexp (Term.from_extracted t) ])
                phis
            in
            Some (decls @ phis)
        | None -> None)
    | _ -> None
end
