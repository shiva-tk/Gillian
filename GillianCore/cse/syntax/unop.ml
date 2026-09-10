type t =
| Not
| Length
| IsInt
| AsInt
| AsNum

let to_extracted op = match op with
  | Not -> Extracted.Op1Not
  | Length -> Extracted.Op1Length
  | IsInt -> Extracted.Op1IsInt
  | AsInt -> Extracted.Op1AsInt
  | AsNum -> Extracted.Op1AsNum
