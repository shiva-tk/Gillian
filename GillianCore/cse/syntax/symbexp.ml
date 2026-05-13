open Extraction_utils

type t =
  | Val of Val.t
  | LVar of string
  | List of t list
  | Unop of Unop.t * t
  | Binop of t * Binop.t * t
  | In of t * Type.t

let rec to_extracted e =
  match e with
  | Val v -> Extracted.SEVal (Val.to_extracted v)
  | LVar x -> Extracted.SEFLVar (Utils.string_to_char_list x)
  | List es -> Extracted.SEList (List.map to_extracted es)
  | Unop (op, e) -> Extracted.SEOp1 (Unop.to_extracted op, to_extracted e)
  | Binop (e1, op, e2) ->
      Extracted.SEOp2 (to_extracted e1, Binop.to_extracted op, to_extracted e2)
  | In (e, ty) -> Extracted.SEIn (to_extracted e, Type.to_extracted ty)
