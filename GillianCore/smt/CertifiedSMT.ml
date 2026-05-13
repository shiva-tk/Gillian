open Gil_syntax

module C : Cse.Smt.Coerce with type exp = Expr.t and type typ = Type.t = struct
  type exp = Expr.t
  type typ = Type.t

  let coerce_type (t : Type.t) : Cse.Type.t option =
    match t with
    | Type.NullType -> Some Cse.Type.Null
    | Type.BooleanType -> Some Cse.Type.Bool
    | Type.IntType -> Some Cse.Type.Nat
    | Type.StringType -> Some Cse.Type.String
    | Type.ListType -> Some (Cse.Type.List Cse.Type.Val)
    | _ -> None

  let rec coerce_val (v : Literal.t) : Cse.Val.t option =
    match v with
    | Null -> Some Cse.Val.Null
    | Bool b -> Some (Cse.Val.Bool b)
    | Int i -> Some (Cse.Val.Nat (Z.to_int i))
    | String s -> Some (Cse.Val.String s)
    | LList vs ->
        let vs =
          List.fold_right
            (fun v acc ->
              match (coerce_val v, acc) with
              | Some v, Some vs -> Some (v :: vs)
              | _ -> None)
            vs (Some [])
        in
        Option.map (fun vs -> Cse.Val.List vs) vs
    | _ -> None

  let coerce_unop (op : UnOp.t) : Cse.Unop.t option =
    match op with
    | Not -> Some Cse.Unop.Not
    | LstLen -> Some Cse.Unop.Length
    | _ -> None

  let coerce_binop (op : BinOp.t) : Cse.Binop.t option =
    match op with
    | Equal -> Some Cse.Binop.Eq
    | ILessThan -> Some Cse.Binop.Lt
    | ILessThanEqual -> None (* TODO *)
    | IPlus -> Some Cse.Binop.Add
    | IMinus -> Some Cse.Binop.Sub
    | IDiv -> Some Cse.Binop.Div
    | IMod -> Some Cse.Binop.Mod
    (* Boolean *)
    | And -> Some Cse.Binop.And
    | Or -> None (* TODO *)
    | Impl -> None (* TODO *)
    | _ -> None

  let rec coerce_symbexp (e : Expr.t) =
    match e with
    | Lit v -> Option.map (fun v -> Cse.Symbexp.Val v) (coerce_val v)
    | LVar x -> Some (Cse.Symbexp.LVar x)
    | UnOp (op, e) -> (
        match (coerce_unop op, coerce_symbexp e) with
        | Some op, Some e -> Some (Cse.Symbexp.Unop (op, e))
        | _ -> None)
    | BinOp (e1, op, e2) -> (
        match (coerce_symbexp e2, coerce_binop op, coerce_symbexp e1) with
        | Some e1, Some op, Some e2 -> Some (Cse.Symbexp.Binop (e1, op, e2))
        | Some e1', None, Some e2' -> (
            match op with
            | ILessThanEqual ->
                coerce_symbexp
                  (Expr.BinOp
                     ( Expr.BinOp (e1, BinOp.ILessThan, e2),
                       BinOp.Or,
                       Expr.BinOp (e1, BinOp.Equal, e2) ))
            | Or ->
                Some
                  (Cse.Symbexp.Unop
                     ( Cse.Unop.Not,
                       Cse.Symbexp.Binop
                         ( Cse.Symbexp.Unop (Cse.Unop.Not, e1'),
                           Cse.Binop.And,
                           Cse.Symbexp.Unop (Cse.Unop.Not, e2') ) ))
            | Impl ->
                coerce_symbexp
                  (Expr.BinOp (Expr.UnOp (UnOp.Not, e1), BinOp.Or, e2))
            | _ -> None)
        | _ -> None)
    | EList es ->
        let es =
          List.fold_right
            (fun e acc ->
              match (coerce_symbexp e, acc) with
              | Some e, Some es -> Some (e :: es)
              | _ -> None)
            es (Some [])
        in
        Option.map (fun es -> Cse.Symbexp.List es) es
    | _ -> None
end

module Smt = Cse.Smt.Make (C)
