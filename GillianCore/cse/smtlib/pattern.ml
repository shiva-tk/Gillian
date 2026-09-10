type t =
  | Var of string
  | App of (Sexplib.Sexp.t * string list)

let to_sexp p =
  let open Sexplib in
  match p with
  | Var x -> Sexp.Atom x
  | App (c, xs) -> Sexp.List (c :: List.map (fun x -> Sexp.Atom x) xs)
