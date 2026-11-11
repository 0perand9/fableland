//! The command vocabulary shared by the CLI and Hyprland keybinds, plus the
//! supervisor that keeps the Quickshell UI running.

use crate::util::Params;
use crate::{d, dispatch, features, log, options, util};
use anyhow::{anyhow, bail, Result};
use serde_json::{json, Value};
use std::path::PathBuf;
use std::process::Stdio;
use std::time::{Duration, Instant};
use tokio::sync::Notify;

#[derive(Default)]
pub struct Ui {
    restart: Notify,
}

/// Popup names accepted by `toggle`/`open`, with the old shell's names as aliases.
fn popup_name(name: &str) -> &str {
    match name {
        "applauncher" | "apps" => "launcher",
        "battery" | "controlcenter" | "power" => "control",
        "focustime" => "focus",
        "updater" => "updates",
        "stewart" => "assistant",
        other => other,
    }
}

/// Ask the shell to open or toggle a popup — one that is there to be opened.
fn show(action: &str, target: &str, arg: &str) -> Result<()> {
    let target = popup_name(target);
    // A popup that is a feature goes by the feature's name.
    if features::exists(target) {
        features::require(target)?;
    }
    d().hub.emit("ui", &json!({ "action": action, "target": target, "arg": arg }));
    Ok(())
}

/// `+5`, `-5` and `40` style arguments: relative change or absolute value.
fn level(arg: &str) -> Result<(bool, f64)> {
    let relative = arg.starts_with('+') || arg.starts_with('-');
    let n: f64 = arg.trim_end_matches('%').parse().map_err(|_| anyhow!("expected a number, got '{arg}'"))?;
    Ok((relative, n))
}

/// Run a command given as words, e.g. `["toggle", "launcher"]`.
pub async fn command(args: &[String]) -> Result<Value> {
    let arg = |i: usize| args.get(i).map(String::as_str).unwrap_or("");
    match arg(0) {
        "ping" => return Ok(json!("pong")),
        "toggle" | "open" => {
            if arg(1).is_empty() {
                bail!("usage: fable {} <popup> [arg]", arg(0));
            }
            show(arg(0), arg(1), arg(2))?;
        }
        "close" => d().hub.emit("ui", &json!({ "action": "close" })),
        "lock" | "logout" | "suspend" | "reboot" | "poweroff" => return dispatch(&format!("session.{}", arg(0)), &Value::Null).await,
        "volume" | "mic" => {
            let kind = if arg(0) == "mic" { "source" } else { "sink" };
            return match arg(1) {
                "mute" | "toggle" => dispatch("audio.toggleMute", &json!({ "kind": kind })).await,
                value => {
                    let (relative, n) = level(value)?;
                    let method = if relative { "audio.step" } else { "audio.setVolume" };
                    dispatch(method, &json!({ "kind": kind, "value": n, "delta": n })).await
                }
            };
        }
        "brightness" => {
            let (relative, n) = level(arg(1))?;
            return dispatch("power.setBrightness", &json!({ "value": n, "relative": relative })).await;
        }
        "media" => {
            let method = match arg(1) {
                "play-pause" | "toggle" | "play" | "pause" => "media.playPause",
                "next" => "media.next",
                "prev" | "previous" => "media.previous",
                other => bail!("unknown media command '{other}'"),
            };
            return dispatch(method, &Value::Null).await;
        }
        "workspace" => return dispatch("hypr.workspace", &json!({ "id": arg(1).parse::<i64>().map_err(|_| anyhow!("workspace needs a number"))? })).await,
        "capture" => return dispatch("capture.start", &json!({ "mode": if arg(1).is_empty() { "region" } else { arg(1) } })).await,
        "wallpaper" => {
            return match arg(1) {
                "next" | "prev" | "random" => dispatch("wallpaper.cycle", &json!({ "direction": arg(1) })).await,
                "" => bail!("usage: fable wallpaper <next|prev|random|PATH>"),
                path => dispatch("wallpaper.apply", &json!({ "path": path })).await,
            };
        }
        "dnd" => {
            let on = match arg(1) {
                "on" => true,
                "off" => false,
                _ => !d().settings.flag("notifications.dnd"),
            };
            return dispatch("notif.setDnd", &json!({ "on": on })).await;
        }
        "reload" => d().ui.restart.notify_one(),
        "restart" => d().restart.notify_one(),
        "" => bail!("no command given"),
        other => bail!("unknown command '{other}' (try: fable help)"),
    }
    Ok(Value::Null)
}

pub async fn call(name: &str, p: &Value) -> Result<Value> {
    match name {
        "toggle" | "open" => show(name, p.str("target")?, p.str_or("arg", ""))?,
        "close" => d().hub.emit("ui", &json!({ "action": "close" })),
        "reload" => d().ui.restart.notify_one(),
        _ => bail!("unknown method ui.{name}"),
    }
    Ok(Value::Null)
}

/// Where the QML lives: an explicit option, an installed copy next to the
/// binary, or the source tree when running from `daemon/target/*`.
pub fn shell_dir() -> Option<PathBuf> {
    if let Some(dir) = &options().shell_dir {
        return Some(dir.clone());
    }
    if let Ok(dir) = std::env::var("FABLE_SHELL_DIR") {
        return Some(PathBuf::from(dir));
    }
    let exe = std::env::current_exe().ok()?;
    let bin = exe.parent()?;
    [bin.join("../share/fableland/shell"), bin.join("../../../shell")].into_iter().find(|p| p.join("shell.qml").exists()).and_then(|p| p.canonicalize().ok())
}

/// Bundled assets (sounds), resolved the same way as the shell directory.
pub fn assets_dir() -> Option<PathBuf> {
    shell_dir().and_then(|s| s.parent().map(|p| p.join("assets"))).filter(|p| p.exists())
}

/// Keep Quickshell alive. It is restarted on crash and on `fable reload`.
pub async fn run() -> Result<()> {
    if options().no_shell {
        return Ok(());
    }
    let Some(dir) = shell_dir() else {
        log!("shell directory not found; start the daemon with --shell-dir or run quickshell yourself");
        return Ok(());
    };
    let bin = util::first_installed(&["quickshell", "qs"]).ok_or_else(|| anyhow!("quickshell is not installed"))?;
    // The guide can greet the user once per session, as soon as the shell is listening.
    if super::hypr::fresh_session() && d().settings.flag("openGuideAtStartup") {
        tokio::spawn(async {
            for _ in 0..150 {
                if d().hub.subscribers() > 0 {
                    break;
                }
                tokio::time::sleep(Duration::from_millis(100)).await;
            }
            tokio::time::sleep(Duration::from_millis(800)).await;
            d().hub.emit("ui", &json!({ "action": "open", "target": "guide", "arg": "" }));
        });
    }
    let mut quick_failures = 0;
    loop {
        let started = Instant::now();
        log!("starting {bin} -p {}", dir.display());
        let mut command = tokio::process::Command::new(bin);
        command
            .arg("-p")
            .arg(&dir)
            .env("FABLE_SOCK", util::socket_path())
            // Software video decoding: hardware decode through VA-API deadlocks Qt on NVIDIA.
            .env("QT_FFMPEG_DECODING_HW_DEVICE_TYPES", "")
            .stdin(Stdio::null())
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .kill_on_drop(true);
        // The shell must not outlive the daemon, however the daemon ends: a
        // second bar would appear when the next daemon starts its own.
        unsafe {
            command.pre_exec(|| {
                libc::prctl(libc::PR_SET_PDEATHSIG, libc::SIGTERM);
                Ok(())
            });
        }
        let mut child = command.spawn()?;
        tokio::select! {
            status = child.wait() => {
                log!("quickshell exited ({})", status.map(|s| s.to_string()).unwrap_or_default());
                quick_failures = if started.elapsed() < Duration::from_secs(3) { quick_failures + 1 } else { 0 };
                // A shell that dies on startup is broken config, not bad luck: back off instead of spinning.
                let wait = if quick_failures >= 4 { 15 } else { 1 };
                tokio::time::sleep(Duration::from_secs(wait)).await;
            }
            _ = d().ui.restart.notified() => {
                let _ = child.kill().await;
                quick_failures = 0;
            }
        }
    }
}
