type t = Val | Null | Bool | Nat | String | List of t

let rec to_extracted (t : t) : Extracted.type0 =
  match t with
  | Val -> Extracted.TVal
  | Null -> Extracted.TNull
  | Bool -> Extracted.TBool
  | Nat -> Extracted.TNat
  | String -> Extracted.TString
  | List t -> Extracted.TList (to_extracted t)
