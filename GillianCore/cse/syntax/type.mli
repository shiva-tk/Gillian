(* Rat and ADT not yet supported in extraction. *)

type t = Val | Null | Bool | Nat | String | List of t

val to_extracted : t -> Extracted.type0
