(* ADT not yet supported in extraction. *)

type t =
  | Val
  | Null
  | None
  | Empty
  | Loc
  | Bool
  | Nat
  | Rat
  | String
  | List of t

val to_extracted : t -> Extracted.type0
