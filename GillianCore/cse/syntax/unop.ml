type t = Not | Length

let to_extracted op =
  match op with
  | Not -> Extracted.Op1Not
  | Length -> Extracted.Op1Length
