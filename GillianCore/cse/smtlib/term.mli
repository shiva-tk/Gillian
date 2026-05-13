type t =
  | Var of string
  | App of (string * t list)
  | Fun of (string * Sort.t * t)
  | Exists of (string * Sort.t * t)
  | Forall of (string * Sort.t * t)
  | Let of ((string * t) list * t)
  | Match of (t * (Pattern.t * t) list)

val from_extracted : Extracted.term -> t
val sanitise_var : string -> string
val to_sexp : t -> Sexplib.Sexp.t
