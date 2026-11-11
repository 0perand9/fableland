//! `fable <command>`: a thin client. Everything except `daemon` is forwarded to
//! the running daemon, so the CLI, Hyprland keybinds and the shell all share one
//! command vocabulary (see `modules/ui.rs::command`).

use crate::util;
use serde_json::{json, Value};
use std::io::{BufRead, BufReader, Write};
use std::os::unix::net::UnixStream;

const HELP: &str = "\
fable — Fableland desktop daemon and control tool

USAGE
  fable daemon [--no-shell] [--shell-dir DIR]   run the daemon (starts the Quickshell UI)
               [--read-only]                    ... observing only: nothing in the session is changed
  fable <command...>                            send a command to the running daemon

COMMANDS
  toggle|open <popup> [arg]     launcher clipboard wallpaper calendar music network volume
                                control focus monitors settings guide updates assistant,
                                and the popup of a plugin by its name (fable get plugins)
  toggle|open quick [tool]      the quick panel; tool: draw system timers
  close                         close the open popup
  lock | logout | suspend | reboot | poweroff
  volume <+N|-N|N|mute>         default output;  mic <+N|-N|N|mute> for the default input
  brightness <+N|-N|N>
  media <play-pause|next|prev>
  workspace <N>
  capture <region|full|edit|ocr|qr|record|stop>
  wallpaper <next|prev|random|PATH>
  dnd [on|off]
  reload                        restart the UI
  restart                       restart the daemon and the UI: after an update, the new build

LOW LEVEL
  fable call <method> [json-params]     e.g. fable call audio.setVolume '{\"value\":40}'
  fable get <topic>                     print the current state of a topic
  fable watch                           stream all state changes and events
";

pub fn run(args: Vec<String>) -> i32 {
    let first = args.first().map(String::as_str).unwrap_or("help");
    if matches!(first, "help" | "--help" | "-h") {
        print!("{HELP}");
        return 0;
    }
    let path = util::socket_path();
    let mut stream = match UnixStream::connect(&path) {
        Ok(s) => s,
        Err(e) => {
            eprintln!("fable: daemon is not running ({}: {e})", path.display());
            return 2;
        }
    };

    let request = match first {
        "watch" => json!({"id": 1, "m": "sub"}),
        "get" => json!({"id": 1, "m": "get", "p": {"topic": args.get(1).cloned().unwrap_or_default()}}),
        "call" => {
            let params: Value = match args.get(2) {
                Some(raw) => match serde_json::from_str(raw) {
                    Ok(v) => v,
                    Err(e) => {
                        eprintln!("fable: params are not valid JSON: {e}");
                        return 2;
                    }
                },
                None => Value::Null,
            };
            json!({"id": 1, "m": args.get(1).cloned().unwrap_or_default(), "p": params})
        }
        _ => json!({"id": 1, "m": "cmd", "p": {"args": args}}),
    };
    if writeln!(stream, "{request}").is_err() {
        eprintln!("fable: lost connection to daemon");
        return 2;
    }

    let reader = BufReader::new(stream);
    for line in reader.lines() {
        let Ok(line) = line else { break };
        if first == "watch" {
            println!("{line}");
            continue;
        }
        let Ok(msg) = serde_json::from_str::<Value>(&line) else { continue };
        if msg.get("id").is_none() {
            continue;
        }
        if msg.get("ok").and_then(Value::as_bool) == Some(true) {
            match msg.get("r") {
                None | Some(Value::Null) => {}
                Some(Value::String(s)) => println!("{s}"),
                Some(other) => println!("{}", serde_json::to_string_pretty(other).unwrap_or_default()),
            }
            return 0;
        }
        eprintln!("fable: {}", msg.get("err").and_then(Value::as_str).unwrap_or("unknown error"));
        return 1;
    }
    if first == "watch" {
        0
    } else {
        eprintln!("fable: daemon closed the connection");
        2
    }
}
