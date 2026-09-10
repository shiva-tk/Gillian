open Extraction_utils

type t =
  | Param of Sexplib.Sexp.t
  | App of (Sexplib.Sexp.t * t list)

let rec from_extracted (s : Extracted.sort) =
  match s with
  | SParam u -> Param (Utils.sexp_of_identifier u)
  | SApp (s, ss) -> App (Utils.sexp_of_identifier s,
                         List.map from_extracted ss)

let rec to_sexp s =
  let open Sexplib in
  match s with
  | Param u -> u
  | App (s, ss) ->
     Sexp.List (s :: (List.map to_sexp ss))
