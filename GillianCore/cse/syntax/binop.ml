type t =
| Eq
| And
| Add
| Sub
| Mul
| Div
| Mod
| Lt
| Cons
| In
| Cat
| Nth
| RAdd
| RSub
| RMul
| RDiv
| RLt
| RLe

let to_extracted op = match op with
  | Eq -> Extracted.Op2Eq
  | And -> Extracted.Op2And
  | Add -> Extracted.Op2Add
  | Sub -> Extracted.Op2Sub
  | Mul -> Extracted.Op2Mul
  | Div -> Extracted.Op2Div
  | Mod -> Extracted.Op2Mod
  | Lt -> Extracted.Op2Lt
  | Cons -> Extracted.Op2Cons
  | In -> Extracted.Op2In
  | Cat -> Extracted.Op2Cat
  | Nth -> Extracted.Op2Nth
  | RAdd -> Extracted.Op2RAdd
  | RSub -> Extracted.Op2RSub
  | RMul -> Extracted.Op2RMul
  | RDiv -> Extracted.Op2RDiv
  | RLt -> Extracted.Op2RLt
  | RLe -> Extracted.Op2RLe
