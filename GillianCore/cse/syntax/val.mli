(* ADT not yet supported in extraction. *)

type t =
  | Null
  | None
  | Empty
  | Loc of int
  | Bool of bool
  | Nat of int
  | Rat of float
  | String of string
  | List of t list

val to_extracted : t -> Extracted.val0
