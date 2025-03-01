open SVal
module L = Logging

(** ****************
  * SATISFIABILITY *
  * **************** **)

let get_axioms (fs : Expr.Set.t) (_ : Type_env.t) : Expr.Set.t =
  Expr.Set.fold
    (fun (pf : Expr.t) (result : Expr.Set.t) ->
      match pf with
      | BinOp (NOp (LstCat, x), Equal, NOp (LstCat, y)) ->
          Expr.Set.add
            (Reduction.reduce_lexpr
               (BinOp
                  ( UnOp (LstLen, NOp (LstCat, x)),
                    Equal,
                    UnOp (LstLen, NOp (LstCat, y)) )))
            result
      | _ -> result)
    fs Expr.Set.empty

let simplify_pfs_and_gamma
    ?(matching = false)
    ?relevant_info
    (fs : Expr.t list)
    (gamma : Type_env.t) : Expr.Set.t * Type_env.t * SESubst.t =
  let pfs, gamma =
    match (relevant_info, !Config.under_approximation) with
    | Some relevant_info, false ->
        ( PFS.filter_with_info relevant_info (PFS.of_list fs),
          Type_env.filter_with_info relevant_info gamma )
    | _ -> (PFS.of_list fs, Type_env.copy gamma)
  in
  let subst, _ = Simplifications.simplify_pfs_and_gamma ~matching pfs gamma in
  let fs_lst = PFS.to_list pfs in
  let fs_set = Expr.Set.of_list fs_lst in
  (fs_set, gamma, subst)

let check_satisfiability_with_model (fs : Expr.t list) (gamma : Type_env.t) :
    SESubst.t option =
  let fs, gamma, subst = simplify_pfs_and_gamma fs gamma in
  let model = Smt.check_sat fs (Type_env.as_hashtbl gamma) in
  let lvars =
    List.fold_left
      (fun ac vs ->
        let vs =
          Expr.Set.of_list (List.map (fun x -> Expr.LVar x) (SS.elements vs))
        in
        Expr.Set.union ac vs)
      Expr.Set.empty
      (List.map Expr.lvars (Expr.Set.elements fs))
  in
  let smt_vars = Expr.Set.diff lvars (SESubst.domain subst None) in
  L.(
    verbose (fun m ->
        m "OBTAINED VARS: %s\n"
          (String.concat ", "
             (List.map
                (fun e -> Format.asprintf "%a" Expr.pp e)
                (Expr.Set.elements smt_vars)))));
  let update x e = SESubst.put subst (LVar x) e in
  match model with
  | None -> None
  | Some model -> (
      try
        Smt.lift_model model (Type_env.as_hashtbl gamma) update smt_vars;
        Some subst
      with e ->
        let () =
          L.verbose (fun m ->
              m "Error when attempting to get SMT model: %s"
                (Printexc.to_string e))
        in
        None)

let check_satisfiability
    ?(matching = false)
    ?time:_
    ?relevant_info
    (fs : Expr.t list)
    (gamma : Type_env.t) : bool =
  (* let t = if time = "" then 0. else Sys.time () in *)
  L.verbose (fun m -> m "Entering FOSolver.check_satisfiability");
  let fs, gamma, _ = simplify_pfs_and_gamma ?relevant_info ~matching fs gamma in
  let axioms = get_axioms fs gamma in
  let fs = Expr.Set.union fs axioms in
  if Expr.Set.is_empty fs then true
  else if Expr.Set.mem Expr.false_ fs then false
  else
    let result = Smt.is_sat fs (Type_env.as_hashtbl gamma) in
    (* if time <> "" then
       Utils.Statistics.update_statistics ("FOS: CheckSat: " ^ time)
         (Sys.time () -. t); *)
    result

let sat ~matching ~pfs ~gamma formula : bool =
  let formula' = Reduction.reduce_lexpr ~matching ~pfs ~gamma formula in
  match formula' with
  | Lit (Bool b) ->
      Logging.verbose (fun fmt ->
          fmt "Discharged sat before SMT @[%a -> %b@]" Expr.pp formula b);
      b
  | _ ->
      let relevant_info =
        (Expr.pvars formula', Expr.lvars formula', Expr.locs formula')
      in
      check_satisfiability ~matching ~relevant_info
        (formula' :: PFS.to_list pfs)
        gamma

(** ************
  * ENTAILMENT *
  * ************ **)

let check_entailment
    ?(matching = false)
    (existentials : SS.t)
    (left_fs : PFS.t)
    (right_fs : Expr.t list)
    (gamma : Type_env.t) : bool =
  L.verbose (fun m ->
      m
        "Preparing entailment check:@\n\
         Existentials:@\n\
         @[<h>%a@]@\n\
         Left:%a@\n\
         Right:%a@\n\
         Gamma:@\n\
         %a@\n"
        (Fmt.iter ~sep:Fmt.comma SS.iter Fmt.string)
        existentials PFS.pp left_fs PFS.pp (PFS.of_list right_fs) Type_env.pp
        gamma);

  (* SOUNDNESS !!DANGER!!: call to simplify_implication       *)
  (* Simplify maximally the implication to be checked         *)
  (* Remove from the typing environment the unused variables  *)
  (* let t = Sys.time () in *)
  let left_fs = PFS.copy left_fs in
  let gamma = Type_env.copy gamma in
  let right_fs = PFS.of_list right_fs in
  let left_lvars = PFS.lvars left_fs in
  let right_lvars = PFS.lvars right_fs in
  let existentials =
    Simplifications.simplify_implication ~matching existentials left_fs right_fs
      gamma
  in
  Type_env.filter_vars_in_place gamma (SS.union left_lvars right_lvars);

  (* Separate gamma into existentials and non-existentials *)
  let left_fs = PFS.to_list left_fs in
  let right_fs = PFS.to_list right_fs in
  let gamma_left =
    Type_env.filter gamma (fun v -> not (SS.mem v existentials))
  in
  let gamma_right = Type_env.filter gamma (fun v -> SS.mem v existentials) in

  (* If left side is false, return false *)
  if List.mem Expr.false_ (left_fs @ right_fs) then false
  else
    (* Check satisfiability of left side *)
    let left_sat =
      true
      (* Smt.check_sat (Formula.Set.of_list left_fs) gamma_left *)
    in

    (* assert (left_sat = true); *)

    (* If the right side is empty or left side is not satisfiable, return the result of
       checking left-side satisfiability *)
    if List.length right_fs = 0 || not left_sat then left_sat
    else
      (* A => B -> Axioms(A) /\ Axioms(B) /\ A => B
                -> !(Axioms(A) /\ Axioms(B) /\ A) \/ B
                -> Axioms(A) /\ Axioms(B) /\ A /\ !B is SAT *)
      (* Existentials in B need to be turned into universals *)
      (* A => Exists (x1, ..., xn) B
                -> Axioms(A) /\ A => (Exists (x1, ..., xn) (Axioms(B) => B)
                -> !(Axioms(A) /\ A) \/ (Exists (x1, ..., xn) (Axioms(B) => B))
                -> Axioms(A) /\ A /\ (ForAll (x1, ..., x2) Axioms(B) /\ !B) is SAT
                -> ForAll (x1, ..., x2)  Axioms(A) /\ Axioms(B) /\ A /\ !B is SAT *)

      (* Get axioms *)
      (* let axioms   = get_axioms (left_fs @ right_fs) gamma in *)
      let right_fs = List.map Expr.negate right_fs in
      let right_f : Expr.t =
        if SS.is_empty existentials then Expr.disjunct right_fs
        else
          let binders =
            List.map
              (fun x -> (x, Type_env.get gamma_right x))
              (SS.elements existentials)
          in
          ForAll (binders, Expr.disjunct right_fs)
      in

      let formulae = PFS.of_list (right_f :: (left_fs @ [] (* axioms *))) in
      let _ = Simplifications.simplify_pfs_and_gamma formulae gamma_left in

      let model =
        Smt.check_sat
          (Expr.Set.of_list (PFS.to_list formulae))
          (Type_env.as_hashtbl gamma_left)
      in
      let ret = Option.is_none model in
      L.(verbose (fun m -> m "Entailment returned %b" ret));
      let () =
        model
        |> Option.iter (fun model ->
               L.tmi (fun m -> m "Here's the model:\n%a" Smt.pp_sexp model))
      in
      (* Utils.Statistics.update_statistics "FOS: CheckEntailment"
         (Sys.time () -. t); *)
      ret

let is_equal ~pfs ~gamma e1 e2 =
  (* let t = Sys.time () in *)
  let feq = Reduction.reduce_lexpr ~gamma ~pfs (BinOp (e1, Equal, e2)) in
  let result =
    match feq with
    | Lit (Bool b) -> b
    | BinOp (_, Equal, _) | BinOp (_, And, _) ->
        check_entailment SS.empty pfs [ feq ] gamma
    | _ ->
        raise
          (Failure
             ("Equality reduced to something unexpected: "
             ^ (Fmt.to_to_string Expr.pp) feq))
  in
  (* Utils.Statistics.update_statistics "FOS: is_equal" (Sys.time () -. t); *)
  result

let is_different ~pfs ~gamma e1 e2 =
  (* let t = Sys.time () in *)
  let feq =
    Reduction.reduce_lexpr ~gamma ~pfs (UnOp (Not, BinOp (e1, Equal, e2)))
  in
  let result =
    match feq with
    | Lit (Bool b) -> b
    | Expr.UnOp (Not, _) -> check_entailment SS.empty pfs [ feq ] gamma
    | _ ->
        raise
          (Failure
             ("Inequality reduced to something unexpected: "
             ^ (Fmt.to_to_string Expr.pp) feq))
  in
  (* Utils.Statistics.update_statistics "FOS: is different" (Sys.time () -. t); *)
  result

let num_is_less_or_equal ~pfs ~gamma e1 e2 =
  let feq =
    Reduction.reduce_lexpr ~gamma ~pfs (Expr.BinOp (e1, FLessThanEqual, e2))
  in
  let result =
    match feq with
    | Lit (Bool b) -> b
    | BinOp (ra, Equal, rb) -> is_equal ~pfs ~gamma ra rb
    | BinOp (_, FLessThanEqual, _) ->
        check_entailment SS.empty pfs [ feq ] gamma
    | _ ->
        raise
          (Failure
             ("Inequality reduced to something unexpected: "
             ^ (Fmt.to_to_string Expr.pp) feq))
  in
  result

let resolve_loc_name ~pfs ~gamma loc =
  Logging.tmi (fun fmt -> fmt "get_loc_name: %a" Expr.pp loc);
  match Reduction.reduce_lexpr ~pfs ~gamma loc with
  | Lit (Loc loc) | ALoc loc -> Some loc
  | loc' -> Reduction.resolve_expr_to_location pfs gamma loc'
