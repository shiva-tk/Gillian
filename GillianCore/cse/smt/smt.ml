open Syntax
open Extraction_utils

module type S = sig
  type exp
  type typ
  type diagnostic = (string * string) list

  type encode_result = {
    coerced : bool;
    encoded : Sexplib.Sexp.t list option;
    coercion_failures : diagnostic list;
    encoding_failures : diagnostic list;
  }

  val decls : Sexplib.Sexp.t list

  val encode_with_diagnostics :
    (string, typ) Hashtbl.t -> exp list -> encode_result

  val encode : (string, typ) Hashtbl.t -> exp list -> Sexplib.Sexp.t list option
end

module type Coerce = sig
  type exp
  type typ

  val coerce_symbexp : exp -> Symbexp.t option
  val coerce_type : typ -> Type.t option
  val string_of_symbexp : exp -> string
  val string_of_type : typ -> string
  val diagnose_symbexp : exp -> string option
  val diagnose_type : typ -> string option
end

module Make (C : Coerce) : S with type exp = C.exp and type typ = C.typ = struct
  type exp = C.exp
  type typ = C.typ
  type diagnostic = (string * string) list

  type encode_result = {
    coerced : bool;
    encoded : Sexplib.Sexp.t list option;
    coercion_failures : diagnostic list;
    encoding_failures : diagnostic list;
  }

  let decls =
    let open Sexplib in
    let atom s = Utils.sexp_of_identifier s in
    let maybe_none = Sexp.Atom "None" in
    [
      Sexp.List
        [
          Sexp.Atom "declare-datatype";
          atom Extracted.s_null;
          Sexp.List [ Sexp.List [ atom Extracted.c_null ] ];
        ];
      Sexp.List
        [
          Sexp.Atom "declare-datatype";
          atom Extracted.s_val;
          Sexp.List
            [
              Sexp.List
                [
                  atom Extracted.c_null_val;
                  Sexp.List [ atom Extracted.g_null_val; atom Extracted.s_null ];
                ];
              Sexp.List [ atom Extracted.c_gillian_none_val ];
              Sexp.List [ atom Extracted.c_gillian_empty_val ];
              Sexp.List
                [
                  atom Extracted.c_gillian_loc_val;
                  Sexp.List
                    [ atom Extracted.g_gillian_loc_val; atom Extracted.s_int ];
                ];
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
      Sexp.List
        [
          Sexp.Atom "declare-datatype";
          atom Extracted.s_maybe_val;
          Sexp.List
            [
              Sexp.List
                [
                  atom Extracted.c_some_val;
                  Sexp.List [ atom Extracted.g_some_val; atom Extracted.s_val ];
                ];
              Sexp.List [ maybe_none ];
            ];
        ];
    ]

  let diagnostic fields = fields

  let field_if_some key = function
    | Some value -> [ (key, value) ]
    | None -> []

  let encode_with_diagnostics typingenv es : encode_result =
    let typingenv_entries =
      Hashtbl.fold (fun x t acc -> (x, t) :: acc) typingenv []
    in
    let typingenv_results =
      List.map
        (fun (x, t) ->
          match C.coerce_type t with
          | Some t' -> Ok (x, Type.to_extracted t')
          | None ->
              let reason =
                Option.value (C.diagnose_type t)
                  ~default:"type coercion returned None"
              in
              Error
                (diagnostic
                   [
                     ("stage", "type-coercion");
                     ("variable", x);
                     ("type", C.string_of_type t);
                     ("reason", reason);
                   ]))
        typingenv_entries
    in
    let expr_results =
      List.mapi
        (fun i e ->
          match C.coerce_symbexp e with
          | Some e' -> Ok (e, Symbexp.to_extracted e')
          | None ->
              let reason =
                Option.value (C.diagnose_symbexp e)
                  ~default:"expression coercion returned None"
              in
              Error
                (diagnostic
                   [
                     ("stage", "expression-coercion");
                     ("index", string_of_int i);
                     ("expression", C.string_of_symbexp e);
                     ("reason", reason);
                   ]))
        es
    in
    let partition_results results =
      List.fold_right
        (fun result (oks, errors) ->
          match result with
          | Ok value -> (value :: oks, errors)
          | Error error -> (oks, error :: errors))
        results ([], [])
    in
    let typingenv_coerced, type_failures =
      partition_results typingenv_results
    in
    let exprs_coerced, expr_failures = partition_results expr_results in
    let coercion_failures = type_failures @ expr_failures in
    let typingenv' = Utils.list_to_gmap_string typingenv_coerced in

    let open Sexplib in
    let open Smtlib in
    (* If both coercions were successful, continue *)
    match coercion_failures with
    | [] -> (
        let encoding_results =
          List.mapi
            (fun i (source_e, e) ->
              let enc =
                Option.bind
                  (Extracted.encode_sexp typingenv' e)
                  Extracted.to_bool
              in
              match enc with
              | Some enc -> Ok enc
              | None ->
                  Error
                    (diagnostic
                       ([
                          ("stage", "verified-encoding");
                          ("index", string_of_int i);
                          ("expression", C.string_of_symbexp source_e);
                          ("reason", "extracted encoder returned None");
                        ]
                       @ field_if_some "coercion_diagnosis"
                           (C.diagnose_symbexp source_e))))
            exprs_coerced
        in
        let encs', encoding_failures = partition_results encoding_results in
        match encoding_failures with
        | [] ->
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
              let s =
                match
                  Extracted.gmap_lookup Extracted.String.eq_dec
                    Extracted.String.countable
                    (Utils.string_to_char_list x)
                    typingenv'
                with
                | Some t -> Extracted.encode_type t
                | None -> Extracted._UU03c3__maybe_val
              in
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
            {
              coerced = true;
              encoded = Some (decls @ phis);
              coercion_failures = [];
              encoding_failures = [];
            }
        | _ ->
            {
              coerced = true;
              encoded = None;
              coercion_failures = [];
              encoding_failures;
            })
    | _ ->
        {
          coerced = false;
          encoded = None;
          coercion_failures;
          encoding_failures = [];
        }

  let encode typingenv es : Sexplib.Sexp.t list option =
    (encode_with_diagnostics typingenv es).encoded
end
