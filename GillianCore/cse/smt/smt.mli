open Syntax

module type S = sig
  type exp
  type typ

  val decls : Sexplib.Sexp.t list
  val encode : (string, typ) Hashtbl.t -> exp list -> Sexplib.Sexp.t list option
end

module type Coerce = sig
  type exp
  type typ

  val coerce_symbexp : exp -> Symbexp.t option
  val coerce_type : typ -> Type.t option
end

module Make : functor (C : Coerce) ->
  S with type exp = C.exp and type typ = C.typ
