(* ADTs and logical functions not yet supported in extraction. *)

type t =
  | Val of Val.t
  | LVar of string
  | List of t list
  | Unop of Unop.t * t
  | Binop of t * Binop.t * t
  | In of t * Type.t

val to_extracted : t -> Extracted.sexp
