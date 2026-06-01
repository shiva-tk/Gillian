open Extraction_utils

type t =
  | Null
  | None
  | Empty
  | Loc of int
  | Bool of bool
  | Nat of int
  | Rat of float
  | String of string
  | List of t list

let rec positive_of_z z =
  if Z.equal z Z.one then Extracted.XH
  else
    let q, r = Z.div_rem z (Z.of_int 2) in
    if Z.equal r Z.zero then Extracted.XO (positive_of_z q)
    else Extracted.XI (positive_of_z q)

let z_of_zarith z =
  match Z.sign z with
  | 0 -> Extracted.Z0
  | n when n > 0 -> Extracted.Zpos (positive_of_z z)
  | _ -> Extracted.Zneg (positive_of_z (Z.neg z))

let q_of_float f =
  match Float.classify_float f with
  | FP_nan | FP_infinite ->
      invalid_arg "Cse.Val.q_of_float: non-finite floats are not Coq Q values"
  | FP_zero | FP_subnormal | FP_normal ->
      let q = Q.of_float f in
      Extracted.q2Qc
        { qnum = z_of_zarith (Q.num q); qden = positive_of_z (Q.den q) }

let rec to_extracted (v : t) =
  match v with
  | Null -> Extracted.PVNull
  | None -> Extracted.PVNone
  | Empty -> Extracted.PVEmpty
  | Loc i -> Extracted.PVLoc i
  | Bool b -> Extracted.PVBool b
  | Nat n -> Extracted.PVNat n
  | Rat r -> Extracted.PVRat (q_of_float r)
  | String s -> Extracted.PVString (Utils.string_to_char_list s)
  | List vs -> Extracted.PVList (List.map to_extracted vs)
