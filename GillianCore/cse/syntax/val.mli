(* Rat and ADT not yet supported in extraction. *)

type t = Null | Bool of bool | Nat of int | String of string | List of t list

val to_extracted : t -> Extracted.val0
