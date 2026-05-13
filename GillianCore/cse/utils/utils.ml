let string_to_char_list s = List.init (String.length s) (String.get s)

let string_from_char_list s =
  let b = Buffer.create (List.length s) in
  List.iter (Buffer.add_char b) s;
  Buffer.contents b

let list_to_gmap_string lst =
  let lst' = List.map (fun (k, v) -> (string_to_char_list k, v)) lst in
  Extracted.list_to_map
    (Extracted.map_insert
       (Extracted.gmap_partial_alter Extracted.String.eq_dec
          Extracted.String.countable))
    (Extracted.gmap_empty Extracted.String.eq_dec Extracted.String.countable)
    lst'

let hashtbl_to_gmap_string tbl =
  let lst = Hashtbl.fold (fun k v acc -> (k, v) :: acc) tbl [] in
  list_to_gmap_string lst
