type t = Param of string | App of (string * t list)

val from_extracted : Extracted.sort -> t
val to_sexp : t -> Sexplib.Sexp.t
