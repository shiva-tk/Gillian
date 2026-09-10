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

let rec to_extracted (t : t) : Extracted.type0 = match t with
  | Val -> Extracted.TVal
  | Null -> Extracted.TNull
  | None -> Extracted.TGillianNone
  | Empty -> Extracted.TGillianEmpty
  | Loc -> Extracted.TGillianLoc
  | Bool -> Extracted.TBool
  | Nat -> Extracted.TNat
  | Rat -> Extracted.TRat
  | String -> Extracted.TString
  | List t -> Extracted.TList (to_extracted t)
