type t =
| Not
| Length
| IsInt
| AsInt
| AsNum

val to_extracted : t -> Extracted.op1
