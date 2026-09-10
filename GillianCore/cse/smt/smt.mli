open Syntax

module type S = sig
  type exp
  type typ
  type diagnostic = (string * string) list

  type encode_result = {
    coerced : bool;
    encoded : Sexplib.Sexp.t list option;
    coercion_failures : diagnostic list;
    encoding_failures : diagnostic list;
  }

  val decls : Sexplib.Sexp.t list

  val encode_with_diagnostics :
    (string, typ) Hashtbl.t -> exp list -> encode_result

  val encode : (string, typ) Hashtbl.t -> exp list -> Sexplib.Sexp.t list option
end

module type Coerce = sig
  type exp
  type typ

  val coerce_symbexp : exp -> Symbexp.t option
  val coerce_type : typ -> Type.t option
  val string_of_symbexp : exp -> string
  val string_of_type : typ -> string
  val diagnose_symbexp : exp -> string option
  val diagnose_type : typ -> string option
end

module Make : functor (C : Coerce) ->
  S with type exp = C.exp and type typ = C.typ
