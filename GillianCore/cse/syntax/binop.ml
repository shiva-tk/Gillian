type t = Eq | And | Add | Sub | Div | Mod | Lt | Cons | In

let to_extracted op =
  match op with
  | Eq -> Extracted.Op2Eq
  | And -> Extracted.Op2And
  | Add -> Extracted.Op2Add
  | Sub -> Extracted.Op2Sub
  | Div -> Extracted.Op2Div
  | Mod -> Extracted.Op2Mod
  | Lt -> Extracted.Op2Lt
  | Cons -> Extracted.Op2Cons
  | In -> Extracted.Op2In
