val string_to_char_list : string -> char list
val string_from_char_list : char list -> string
val list_to_gmap_string : (string * 'a) list -> (char list, 'a) Extracted.gmap

val hashtbl_to_gmap_string :
  (string, 'a) Hashtbl.t -> (char list, 'a) Extracted.gmap
