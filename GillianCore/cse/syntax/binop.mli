type t =
  | Eq
  | And
  | Add
  | Sub
  | Div
  | Mod
  | Lt
  | Cons
  | In
  | RAdd
  | RSub
  | RDiv
  | RLt
  | RLe

val to_extracted : t -> Extracted.op2
