type t = Var of string | App of (string * string list)

let to_sexp p =
  let open Sexplib in
  match p with
  | Var x -> Sexp.Atom x
  | App (c, xs) -> Sexp.List (List.map (fun x -> Sexp.Atom x) (c :: xs))
