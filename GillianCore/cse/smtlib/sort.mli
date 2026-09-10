type t =
  | Param of Sexplib.Sexp.t
  | App of (Sexplib.Sexp.t * t list)

val from_extracted : Extracted.sort -> t

val to_sexp : t -> Sexplib.Sexp.t
