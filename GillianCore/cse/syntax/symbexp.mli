(* ADTs and logical functions not yet supported in extraction. *)

type t =
| Val of Val.t
| LVar of string
| List of t list
| Unop of Unop.t * t
| Binop of t * Binop.t * t
| In of t * Type.t

(* The logical variables the expression mentions, without duplicates. *)
val lvars : t -> string list

val to_extracted : t -> Extracted.sexp
