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

val to_extracted : t -> Extracted.op2
