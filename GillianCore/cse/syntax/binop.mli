type t = Eq | And | Add | Sub | Div | Mod | Lt | Cons | In

val to_extracted : t -> Extracted.op2
