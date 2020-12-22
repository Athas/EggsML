(* Helper program for the årquiz game. *)

open Core
open Async

let base_url = "https://da.wikipedia.org/w/api.php?action=parse&format=json&prop=parsetree&page="

let rec find_substring string start sub =
  if start + String.length sub <= String.length string
  then let sub' = String.sub string ~pos:start ~len:(String.length sub) in
       if String.equal sub' sub
       then start
       else find_substring string (start + 1) sub
  else -1

(* This is just plain inefficient. *)
let rec replace string start old repl =
  if start + String.length old <= String.length string
  then let sub = String.sub string ~pos:start ~len:(String.length old) in
       if String.equal sub old
       then repl ^ replace string (start + String.length old) old repl
       else String.sub string ~pos:start ~len:1 ^ replace string (start + 1) old repl
  else String.sub string ~pos:start ~len:(String.length string - start)

let rec remove_link_artefacts string start =
  let rest () = String.sub string ~pos:start ~len:(String.length string - start) in
  let a = find_substring string start "[[" in
  if a <> -1
  then let c = find_substring string a "]]" in
       if c <> -1
       then let b = find_substring string a "|" in
            if b <> -1 && a < b && b < c
            then String.sub string ~pos:start ~len:(a - start) ^ String.sub string ~pos:(b + 1) ~len:(c - (b + 1)) ^ remove_link_artefacts string c
            else String.sub string ~pos:start ~len:(c + 2 - start) ^ remove_link_artefacts string (c + 2)
       else rest ()
  else rest ()

let rec remove_ext_artefacts string start =
  let ext_start = find_substring string start "<ext" in
  let ext_end = if ext_start <> -1
                then find_substring string ext_start "</ext>"
                else -1 in
  if ext_end <> -1
  then String.sub string ~pos:start ~len:ext_start
       ^ remove_ext_artefacts string (ext_end + String.length "</ext>")
  else String.sub string ~pos:start ~len:(String.length string - start)

let parse_events text header =
  let events_start = find_substring text 0 header in
  if events_start <> -1
  then let events_end = find_substring text events_start "\n\n<h level=\"2\"" in
       let events_end = if events_end = -1 then find_substring text events_start "\n\n" else events_end in
       let rec find_events cur_start =
         let sub_start = find_substring text cur_start "\n* " in
         if sub_start <> -1 && sub_start < events_end
         then let sub_end = find_substring text (sub_start + 1) "\n" in
              let line = String.sub text ~pos:(sub_start + 3) ~len:(sub_end - sub_start - 3) in
              let line = remove_link_artefacts line 0 in
              let line = remove_ext_artefacts line 0 in
              let date_dash1 = "]] - " in
              let date_dash2 = "]] – " in
              let dash1 = find_substring line 0 date_dash1 in
              let dash2 = find_substring line 0 date_dash2 in
              let (date_dash, dash) = if dash2 = -1
                                      then (date_dash1, dash1)
                                      else if dash1 = -1
                                      then (date_dash2, dash2)
                                      else if dash1 < dash2
                                      then (date_dash1, dash1)
                                      else (date_dash2, dash2) in
              let line = if dash <> -1
                         then String.sub line ~pos:(dash + String.length date_dash)
                                ~len:(String.length line - (dash + String.length date_dash))
                         else line in
              let line = replace (replace (replace (replace line 0 "[[" "") 0 "]]" "") 0 "'''" "**") 0 "''" "*"
              in line :: find_events sub_end
         else []
       in find_events events_start
  else []

let ok_sport s =
  find_substring s 0 "vinde" <> -1
  || find_substring s 0 "tabe" <> -1
  || find_substring s 0 "besejre" <> -1
  || find_substring s 0 "forsvare" <> -1
  || find_substring s 0 "holde" <> -1
  || find_substring s 0 "stifte" <> -1
  || find_substring s 0 "anlægge" <> -1
  || find_substring s 0 "sætte" <> -1

let ok_musik s =
  find_substring s 0 "vinde" <> -1
  || find_substring s 0 "tabe" <> -1
  || find_substring s 0 "hitte" <> -1
  || find_substring s 0 "danne" <> -1
  || find_substring s 0 "udgive" <> -1
  || find_substring s 0 "udsende" <> -1
  || find_substring s 0 "spille" <> -1

let parse text =
  let begivenheder = parse_events text "== Begivenheder ==" in
  let sport = parse_events text "== Sport ==" in
  let sport = List.filter ~f:ok_sport sport in
  let musik = parse_events text "== Musik ==" in
  let musik = List.filter ~f:ok_musik musik in
  begivenheder @ sport @ musik

module Tup = struct
  include Tuple.Comparable (Int) (String)
end

let shuffle d =
    let nd = List.map ~f:(fun c -> (Random.bits (), c)) d in
    let sond = List.sort ~compare:Tup.compare nd in
    List.map ~f:snd sond

let rec find_year_facts () =
  Random.self_init ();
  let year = 0 + Random.int 2020 in (* XXX: Better distribution *)
  let url = base_url ^ string_of_int year in
  Cohttp_async.Client.get (Uri.of_string url) >>= fun (_, body) ->
  Cohttp_async.Body.to_string body >>= fun json ->
  let open Yojson.Basic.Util in
  let text = Yojson.Basic.from_string json |> member "parse" |> member "parsetree" |> member "*" |> to_string in
  let text = replace text 0 (string_of_int year) "XXXX" in
  let lines = parse text in
  if List.length lines = 0 || (List.length lines = 1 && String.length (List.nth_exn lines 0) = 0)
  then find_year_facts ()
  else let lines = shuffle lines in
       let lines = List.init (min 3 (List.length lines)) ~f:(List.nth_exn lines) in
       printf "%d %d\n" year (List.length lines);
       List.iteri ~f:(printf "%d. %s\n") lines;
       Deferred.unit

(* This seems kind of overcomplicated. *)
let () =
   don't_wait_for (find_year_facts () >>| fun _ -> shutdown 0);
   never_returns (Scheduler.go ())
