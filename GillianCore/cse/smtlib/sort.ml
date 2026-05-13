open Extraction_utils

type t = Param of string | App of (string * t list)

let rec from_extracted (s : Extracted.sort) =
  match s with
  | SParam u -> Param (Utils.string_from_char_list u)
  | SApp (s, ss) ->
      App (Utils.string_from_char_list s, List.map from_extracted ss)

let rec to_sexp s =
  let open Sexplib in
  match s with
  | Param u -> Sexp.Atom u
  | App (s, ss) -> Sexp.List (Sexp.Atom s :: List.map to_sexp ss)
