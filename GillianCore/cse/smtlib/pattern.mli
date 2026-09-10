type t =
  | Var of string
  | App of (Sexplib.Sexp.t * string list)

val to_sexp : t -> Sexplib.Sexp.t
