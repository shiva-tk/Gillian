type t = Var of string | App of (string * string list)

val to_sexp : t -> Sexplib.Sexp.t
