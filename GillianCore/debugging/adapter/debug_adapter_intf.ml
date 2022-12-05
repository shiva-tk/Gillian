module type S = sig
  val start : Lwt_io.input_channel -> Lwt_io.output_channel -> unit Lwt.t
end

module type Make = functor (Debugger : Debugger.S) -> S

module type Intf = sig
  module type S = S
  module type Make = Make

  module Make : Make
end
