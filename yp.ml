module U = Uri

type handler =
  | Youtubedl of string
  | Livestreamer of string
  | Unsupported


(* return channel contents as arrays of strings *)
let read_lines ch =
  let rec read lines =
    try
      let line = input_line ch in
      read (line :: lines)
    with
    | End_of_file -> List.rev lines
  in
  read []


(* read whole process output as an array of strings *)
let read_process_output cmd =
  let open Unix in
  let ch = open_process_in cmd in
  try
    let lines = read_lines ch in
    match close_process_in ch with
    | WEXITED 0 -> Some lines
    | _ -> None
  with
  | _ -> ignore @@ close_process_in ch; None


let read_clipboard () =
  match read_process_output "xclip -o -selection clipboard" with
  | Some (line :: _) -> Some (String.trim line)
  | _ -> None


let youtube_dl url =
  match read_process_output ("~/scripts/youtube-dl -g -f 18/22 " ^ url) with
  | Some (url :: []) -> Unix.execvp "mplayer" [|"mplayer"; "-cache"; "2048"; url|]
  | _ -> print_endline "OOPS"


let map_uri uri =
  match Uri.host uri with
  | Some "youtube.com"
  | Some "www.youtube.com"
  | Some "ytimg.com"
  | Some "youtu.be" ->
    Youtubedl (Uri.query uri |> List.filter (fun (k, _) -> String.equal k "v") |> Uri.with_query uri |> Uri.to_string)
  | _ -> Unsupported


let notify msg =
  let open Lwt.Infix in
  let n = Notification.notify ~summary:"Player" ~body:("Playing " ^ msg) ~timeout:3000 () >>= Notification.result >>= (fun r -> Lwt.return (`Notification r))
  and wait = Lwt_unix.sleep 2. >>= (fun _ -> Lwt.return `Timeout) in
  match%lwt Lwt.pick [n; wait] with
  | `Notification _ -> Lwt_io.printl "Notification"
  | `Timeout -> Lwt_io.printl "Timeout"


let handle_uri uri =
  match map_uri uri with
  | Youtubedl vid -> youtube_dl vid
  | Livestreamer vid -> Printf.printf "livestreamer %s\n" vid
  | _ -> print_endline "UNSUPPORTED"


let with_pipe_in body =
  let open Lwt.Infix in
  let p = Lwt_unix.pipe_in () in
  let stream = Lwt_io.of_fd ~mode:Lwt_io.Input (fst p) |> Lwt_io.read_lines in
  begin
    body stream (snd p) (*>>= (fun r -> Lwt_unix.close (fst p) >|= (fun () -> r))*)
  end [%finally Lwt_unix.close (fst p)]


let zz =
  with_pipe_in (fun out out_fd -> with_pipe_in (fun err err_fd ->
      Lwt.return (out, err)))

let read_process cmd =
  let open Lwt.Infix in
  let stdout_p = Lwt_unix.pipe_in () in
  let stderr_p = Lwt_unix.pipe_in () in
  let stdout = Lwt_io.of_fd ~mode:Lwt_io.Input (fst stdout_p) |> Lwt_io.read_lines in
  let stderr = Lwt_io.of_fd ~mode:Lwt_io.Input (fst stderr_p) |> Lwt_io.read_lines in
  let read_stream s = Lwt_stream.fold (fun x xs -> x :: xs) s [] >|= List.rev in
  let ps = Lwt_process.open_process_none ~stdin:`Dev_null ~stdout:(`FD_move (snd stdout_p)) ~stderr:(`FD_move (snd stderr_p)) cmd in

  let result =
    let%lwt pend = Lwt_unix.waitpid [] ps#pid
    and stdout_lines = read_stream stdout
    and stderr_lines = read_stream stderr in
    let%lwt () = Lwt_unix.close (fst stdout_p)
    and () = Lwt_unix.close (fst stderr_p) in
    Lwt.return (snd pend, stdout_lines, stderr_lines)
  in
  Lwt.on_any result (fun _ -> print_endline "<success>") (fun _ -> print_endline "<exn>");
  result

let () =
  let prn prefix lines =
    List.iter (fun line -> Printf.printf "%s> %s\n" prefix line) lines
  in
  let status, out, err = read_process ("./out", [|"./out"|]) |> Lwt_main.run in
  let () =
    prn "OUT" out;
    prn "ERR" err;
    match status with
    | Unix.WEXITED code -> Printf.printf "EXITED> %d\n" code
    | Unix.WSIGNALED signal -> Printf.printf "SIGNAL> %d\n" signal
    | _ -> print_endline "STOPPED?"
  in
  Unix.system (Printf.sprintf "ls -l /proc/%d/fd" @@ Unix.getpid ()) |> ignore
  (*notify "video" |> Lwt_main.run*)
  (*match read_clipboard() with
  | Some "" | None -> prerr_endline "Unable to read clipboard"
  | Some s -> handle_uri @@ Uri.of_string s |> ignore*)
