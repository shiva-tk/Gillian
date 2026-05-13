open Extraction_utils

type t = Null | Bool of bool | Nat of int | String of string | List of t list

let rec to_extracted (v : t) =
  match v with
  | Null -> Extracted.PVNull
  | Bool b -> Extracted.PVBool b
  | Nat n -> Extracted.PVNat n
  | String s -> Extracted.PVString (Utils.string_to_char_list s)
  | List vs -> Extracted.PVList (List.map to_extracted vs)
