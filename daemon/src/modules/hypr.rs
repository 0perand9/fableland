//! Hyprland bridge.
//!
//! Reads the compositor's event socket, keeps the `hypr` and `monitors` topics
//! current, and is the only place that sends commands to Hyprland. It also
//! applies the settings Hyprland's own config does not know about: user
//! keybinds, keyboard layouts, the saved monitor layout and startup commands.
//!
//! Keybinds reach the daemon without spawning a process: the Hyprland config
//! binds `hl.dsp.event("fable toggle launcher")`, Hyprland emits
//! `custom>>fable toggle launcher` on its event socket, and we run it.

use crate::util::{lua_str, Params};
use crate::{d, log, util};
use anyhow::{anyhow, bail, Result};
use serde_json::{json, Value};
use std::path::PathBuf;
use std::sync::Mutex;
use std::time::Duration;
use tokio::io::{AsyncBufReadExt, AsyncReadExt, AsyncWriteExt, BufReader};
use tokio::net::UnixStream;
use tokio::sync::Notify;

#[derive(Default)]
pub struct Hypr {
    dirty: Notify,
    kb_dirty: Notify,
    submap: Mutex<String>,
    layout: Mutex<(String, String)>,
    /// (class, title) of the focused window; empty class means the desktop.
    window: Mutex<(String, String)>,
    /// Keys of user keybinds currently registered, so they can be unbound on change.
    applied_binds: Mutex<Vec<String>>,
}

fn instance() -> Option<String> {
    std::env::var("HYPRLAND_INSTANCE_SIGNATURE").ok().filter(|s| !s.is_empty())
}

fn socket(name: &str) -> Option<PathBuf> {
    let runtime = std::env::var("XDG_RUNTIME_DIR").ok()?;
    Some(PathBuf::from(runtime).join("hypr").join(instance()?).join(name))
}

/// Send one raw request to Hyprland and return its reply.
pub async fn request(cmd: &str) -> Result<String> {
    // A read-only daemon only asks Hyprland questions.
    if crate::options().read_only && !(cmd.starts_with("j/") || cmd.starts_with("[[BATCH]]j/") || cmd == "version") {
        return Ok("ok".into());
    }
    let path = socket(".socket.sock").ok_or_else(|| anyhow!("not running under Hyprland"))?;
    let mut stream = UnixStream::connect(path).await?;
    stream.write_all(cmd.as_bytes()).await?;
    let mut out = String::new();
    stream.read_to_string(&mut out).await?;
    Ok(out)
}

async fn query(what: &str) -> Result<Value> {
    Ok(serde_json::from_str(&request(&format!("j/{what}")).await?)?)
}

/// `hl.bind(...)` calls found in the user's Lua config: (modifiers, key, action text, runs a command).
///
/// Hyprland cannot describe a Lua bind (the action is an opaque function), so
/// for the keybind cheat-sheet the source is the only place that says what a
/// key does. Only binds whose keys are written as one literal are understood.
fn binds_in_config() -> Vec<(Vec<String>, String, String, bool)> {
    let config = std::env::var("XDG_CONFIG_HOME").map(PathBuf::from).unwrap_or_else(|_| util::home().join(".config")).join("hypr/hyprland.lua");
    let text = std::fs::read_to_string(config).unwrap_or_default();
    let mut found = Vec::new();
    for line in text.lines() {
        let line = line.trim();
        let Some(args) = line.strip_prefix("hl.bind(") else { continue };
        // The first argument ends at the first comma outside quotes and brackets.
        let (mut depth, mut quote, mut split) = (0i32, None, None);
        for (i, c) in args.char_indices() {
            match (quote, c) {
                (Some(q), _) if c == q => quote = None,
                (Some(_), _) => {}
                (None, '"' | '\'') => quote = Some(c),
                (None, '(' | '{' | '[') => depth += 1,
                (None, ')' | '}' | ']') => depth -= 1,
                (None, ',') if depth == 0 => {
                    split = Some(i);
                    break;
                }
                _ => {}
            }
        }
        let Some(split) = split else { continue };
        let (keys, rest) = (&args[..split], args[split + 1..].trim());
        if keys.contains("..") {
            continue;
        }
        let Some(spec) = keys.split('"').nth(1) else { continue };
        let mut parts: Vec<String> = spec.split('+').map(|p| p.trim().to_string()).filter(|p| !p.is_empty()).collect();
        let Some(key) = parts.pop() else { continue };
        // The action runs to the parenthesis that closes it (options or the end of hl.bind follow).
        let (mut depth, mut quote, mut end) = (0i32, None, rest.len());
        for (i, c) in rest.char_indices() {
            match (quote, c) {
                (Some(q), _) if c == q => quote = None,
                (Some(_), _) => {}
                (None, '"' | '\'') => quote = Some(c),
                (None, '(' | '{' | '[') => depth += 1,
                (None, ')' | '}' | ']') => {
                    depth -= 1;
                    if depth <= 0 {
                        end = if depth == 0 { i + 1 } else { i };
                        break;
                    }
                }
                _ => {}
            }
        }
        let action = rest[..end].trim().trim_start_matches("hl.dsp.");
        // exec("kitty") reads better as just the command.
        let (action, is_exec) = match action.split_once('(') {
            Some(("exec" | "exec_cmd", arg)) => (arg.trim_end_matches(')').trim().trim_matches(['"', '\'']).to_string(), true),
            _ => (action.to_string(), false),
        };
        found.push((parts.iter().map(|m| m.to_uppercase()).collect(), key, action, is_exec));
    }
    found
}

/// Every keybind, in a form the UI can show: modifiers, key and what it does.
async fn binds() -> Result<Value> {
    const MODS: [(u64, &str); 4] = [(64, "SUPER"), (4, "CTRL"), (8, "ALT"), (1, "SHIFT")];
    let raw = query("binds").await?;
    let mut source = tokio::task::spawn_blocking(binds_in_config).await?;
    let mut out = Vec::new();
    for b in raw.as_array().map(|a| a.as_slice()).unwrap_or_default() {
        let mask = b["modmask"].as_u64().unwrap_or(0);
        let mods: Vec<&str> = MODS.iter().filter(|(bit, _)| mask & bit != 0).map(|(_, name)| *name).collect();
        let key = match b["key"].as_str().unwrap_or("") {
            "" => format!("code:{}", b["keycode"]),
            k => k.to_string(),
        };
        let raw_dispatcher = b["dispatcher"].as_str().unwrap_or("");
        let lua = raw_dispatcher.starts_with("HL.Dispatcher(");
        // A bind to a plain Lua function has nothing but the function's address for a name.
        let dispatcher = if raw_dispatcher.starts_with("function") { "lua" } else { raw_dispatcher.trim_start_matches("HL.Dispatcher(").trim_end_matches(')') };
        let lua = lua || dispatcher == "lua";
        let mut action = b["description"].as_str().unwrap_or("").to_string();
        if action.is_empty() && !lua {
            action = format!("{dispatcher} {}", b["arg"].as_str().unwrap_or("")).trim().to_string();
        }
        if action.is_empty() {
            // The closest bind in the config: same key, the same kind of action and no modifier
            // this bind lacks. Binds are registered in file order, so the earliest candidate wins ties.
            let alias = |m: &String| if m == "CONTROL" { "CTRL".to_string() } else { m.clone() };
            let best = source
                .iter()
                .enumerate()
                .filter(|(_, (smods, skey, action, is_exec))| {
                    skey.eq_ignore_ascii_case(&key) && smods.iter().all(|m| mods.contains(&alias(m).as_str())) && if dispatcher == "exec_cmd" { *is_exec } else { !is_exec && action.contains(dispatcher) }
                })
                .min_by_key(|(_, (smods, ..))| std::cmp::Reverse(smods.len()))
                .map(|(i, _)| i);
            if let Some(i) = best {
                action = source.remove(i).2;
            }
        }
        out.push(json!({
            "mods": mods, "key": key, "dispatcher": dispatcher, "action": action,
            "mouse": b["mouse"], "repeat": b["repeat"], "locked": b["locked"], "submap": b["submap"],
        }));
    }
    Ok(json!(out))
}

fn check(reply: String) -> Result<()> {
    let r = reply.trim();
    if r.is_empty() || r == "ok" {
        Ok(())
    } else {
        bail!("Hyprland: {r}")
    }
}

/// Run a dispatcher, e.g. `hl.dsp.focus({ workspace = 3 })`.
pub async fn dispatch(lua: &str) -> Result<()> {
    check(request(&format!("dispatch {lua}")).await?)
}

/// Evaluate Lua in the compositor's config context.
pub async fn eval(lua: &str) -> Result<()> {
    check(request(&format!("eval {lua}")).await?)
}

/// Launch a program as a child of the compositor (not of the daemon).
pub async fn exec(command: &str) -> Result<()> {
    if instance().is_some() {
        dispatch(&format!("hl.dsp.exec_cmd({})", lua_str(command))).await
    } else {
        util::spawn_detached("sh", &["-c", command]);
        Ok(())
    }
}

impl Hypr {
    /// (class, title) of the focused window.
    pub fn focused_window(&self) -> (String, String) {
        self.window.lock().unwrap().clone()
    }
}

pub async fn run() -> Result<()> {
    if instance().is_none() {
        log!("HYPRLAND_INSTANCE_SIGNATURE is not set; Hyprland integration disabled");
        d().hub.publish("hypr", &json!({ "available": false, "workspaces": [], "active": 1 }));
        return Ok(());
    }
    tokio::spawn(refresher());
    tokio::spawn(keyboard_refresher());
    tokio::spawn(settings_watcher());
    d().hypr.dirty.notify_one();
    d().hypr.kb_dirty.notify_one();
    if let Err(e) = apply_settings(true).await {
        log!("applying Hyprland settings: {e:#}");
    }
    run_startup_commands().await;

    loop {
        if let Err(e) = events().await {
            log!("Hyprland event socket: {e:#}");
        }
        // Hyprland removes its lock file on exit. A daemon outliving its
        // session would hold the socket the next session's daemon needs, and
        // hear none of its keybinds.
        if socket("hyprland.lock").is_some_and(|lock| !lock.exists()) {
            log!("Hyprland session {} has ended", instance().unwrap_or_default());
            d().quit.notify_one();
            return Ok(());
        }
        tokio::time::sleep(Duration::from_secs(1)).await;
    }
}

async fn events() -> Result<()> {
    let path = socket(".socket2.sock").ok_or_else(|| anyhow!("no event socket"))?;
    let stream = UnixStream::connect(path).await?;
    let mut lines = BufReader::new(stream).lines();
    let h = &d().hypr;
    h.dirty.notify_one();
    while let Some(line) = lines.next_line().await? {
        let (event, data) = line.split_once(">>").unwrap_or((&line, ""));
        match event {
            "custom" => {
                if let Some(cmd) = data.strip_prefix("fable ") {
                    let args: Vec<String> = cmd.split_whitespace().map(String::from).collect();
                    tokio::spawn(async move {
                        if let Err(e) = super::ui::command(&args).await {
                            log!("keybind command '{}' failed: {e:#}", args.join(" "));
                            d().hub.toast("error", "Command failed", &format!("{e:#}"));
                        }
                    });
                }
            }
            "submap" => {
                *h.submap.lock().unwrap() = data.to_string();
                h.dirty.notify_one();
            }
            "activelayout" => h.kb_dirty.notify_one(),
            "configreloaded" => {
                // A reload drops everything that was registered at runtime.
                h.applied_binds.lock().unwrap().clear();
                tokio::spawn(async {
                    if let Err(e) = apply_settings(false).await {
                        log!("re-applying settings after reload: {e:#}");
                    }
                    super::wallpaper::apply_border_colors().await;
                });
                h.dirty.notify_one();
                h.kb_dirty.notify_one();
            }
            e if e.starts_with("workspace")
                || e.starts_with("focusedmon")
                || e.starts_with("createworkspace")
                || e.starts_with("destroyworkspace")
                || e.starts_with("moveworkspace")
                || e.starts_with("renameworkspace")
                || e.starts_with("activespecial")
                || e.starts_with("activewindow")
                || e.starts_with("windowtitle")
                || e.starts_with("movewindow")
                || e.starts_with("monitoradded")
                || e.starts_with("monitorremoved")
                || matches!(e, "openwindow" | "closewindow" | "fullscreen" | "changefloatingmode") =>
            {
                h.dirty.notify_one()
            }
            _ => {}
        }
    }
    bail!("event socket closed")
}

/// Coalesces bursts of events into one batched query.
async fn refresher() {
    let h = &d().hypr;
    loop {
        h.dirty.notified().await;
        tokio::time::sleep(Duration::from_millis(8)).await;
        if let Err(e) = refresh().await {
            log!("Hyprland refresh: {e:#}");
            tokio::time::sleep(Duration::from_millis(500)).await;
        }
    }
}

async fn refresh() -> Result<()> {
    let raw = request("[[BATCH]]j/workspaces;j/monitors;j/activewindow").await?;
    let mut docs = serde_json::Deserializer::from_str(&raw).into_iter::<Value>();
    let (Some(Ok(ws)), Some(Ok(mons)), Some(Ok(win))) = (docs.next(), docs.next(), docs.next()) else {
        bail!("unexpected reply to batched query");
    };
    let h = &d().hypr;

    let mut workspaces: Vec<Value> = ws
        .as_array()
        .map(|a| a.as_slice())
        .unwrap_or_default()
        .iter()
        .filter(|w| w["id"].as_i64().unwrap_or(-1) > 0)
        .map(|w| json!({ "id": w["id"], "name": w["name"], "windows": w["windows"], "monitor": w["monitor"], "title": w["lastwindowtitle"] }))
        .collect();
    workspaces.sort_by_key(|w| w["id"].as_i64().unwrap_or(0));

    let mut focused_monitor = String::new();
    let mut active = 1;
    let mut monitor_active = serde_json::Map::new();
    let mut monitors = Vec::new();
    for m in mons.as_array().map(|a| a.as_slice()).unwrap_or_default() {
        let name = m["name"].as_str().unwrap_or("").to_string();
        let ws_id = m["activeWorkspace"]["id"].as_i64().unwrap_or(1);
        if m["focused"].as_bool().unwrap_or(false) {
            focused_monitor = name.clone();
            active = ws_id;
        }
        monitor_active.insert(name.clone(), json!(ws_id));
        monitors.push(json!({
            "name": name, "description": m["description"], "make": m["make"], "model": m["model"],
            "width": m["width"], "height": m["height"], "refreshRate": m["refreshRate"],
            "scale": m["scale"], "transform": m["transform"], "x": m["x"], "y": m["y"],
            "focused": m["focused"], "modes": m["availableModes"],
        }));
    }

    let class = win["class"].as_str().unwrap_or("").to_string();
    let title = win["title"].as_str().unwrap_or("").to_string();
    *h.window.lock().unwrap() = (class.clone(), title.clone());
    let (layout, layout_name) = h.layout.lock().unwrap().clone();

    d().hub.publish("monitors", &monitors);
    d().hub.publish(
        "hypr",
        &json!({
            "available": true,
            "workspaces": workspaces,
            "active": active,
            "focusedMonitor": focused_monitor,
            "monitorActive": monitor_active,
            "window": {
                "class": class, "title": title, "address": win["address"],
                "fullscreen": win["fullscreen"].as_i64().unwrap_or(0) > 0,
                "floating": win["floating"].as_bool().unwrap_or(false),
            },
            "layout": layout,
            "layoutName": layout_name,
            "submap": *h.submap.lock().unwrap(),
        }),
    );
    Ok(())
}

async fn keyboard_refresher() {
    let h = &d().hypr;
    loop {
        h.kb_dirty.notified().await;
        if let Ok(devices) = query("devices").await {
            let keyboards = devices["keyboards"].as_array().cloned().unwrap_or_default();
            let main = keyboards.iter().find(|k| k["main"].as_bool() == Some(true)).or(keyboards.first());
            if let Some(name) = main.and_then(|k| k["active_keymap"].as_str()) {
                let short: String = name.chars().filter(|c| c.is_alphabetic()).take(2).collect::<String>().to_uppercase();
                *h.layout.lock().unwrap() = (short, name.to_string());
                h.dirty.notify_one();
            }
        }
    }
}

// ---------------------------------------------------------------- settings → Hyprland

async fn settings_watcher() {
    let s = &d().settings;
    let mut rx = s.changes();
    let mut seen = (s.get("keybinds"), s.get("keyboard"));
    while rx.changed().await.is_ok() {
        let now = (s.get("keybinds"), s.get("keyboard"));
        if now != seen {
            seen = now;
            if let Err(e) = apply_settings(false).await {
                d().hub.toast("error", "Hyprland", &format!("{e:#}"));
            }
        }
    }
}

fn bind_lua(bind: &Value) -> Option<(String, String)> {
    let keys = bind["keys"].as_str().filter(|k| !k.trim().is_empty())?.trim().to_string();
    let command = bind["command"].as_str().unwrap_or("").trim();
    if command.is_empty() {
        return None;
    }
    let action = match bind["action"].as_str().unwrap_or("exec") {
        "fable" => format!("hl.dsp.event({})", lua_str(&format!("fable {command}"))),
        "lua" => command.to_string(),
        _ => format!("hl.dsp.exec_cmd({})", lua_str(command)),
    };
    let mut opts = Vec::new();
    if bind["repeat"].as_bool() == Some(true) {
        opts.push("repeating = true".to_string());
    }
    if bind["locked"].as_bool() == Some(true) {
        opts.push("locked = true".to_string());
    }
    // Hyprland cannot say what a Lua bind does, so every bind carries a description:
    // the user's, or the command itself. `hypr.binds` reports it as the bind's action.
    let description = match (bind["description"].as_str().filter(|s| !s.is_empty()), bind["action"].as_str().unwrap_or("exec")) {
        (Some(text), _) => text.to_string(),
        (None, "fable") => format!("fable {command}"),
        (None, _) => command.to_string(),
    };
    opts.push(format!("description = {}", lua_str(&description)));
    Some((keys.clone(), format!("hl.bind({}, {}, {{ {} }})", lua_str(&keys), action, opts.join(", "))))
}

/// Push user keybinds and keyboard layouts into the running compositor.
/// With `startup` the saved monitor layout is restored as well.
pub async fn apply_settings(startup: bool) -> Result<()> {
    let s = &d().settings;
    let h = &d().hypr;
    let mut errors = Vec::new();

    let previous: Vec<String> = std::mem::take(&mut *h.applied_binds.lock().unwrap());
    for keys in previous {
        let _ = eval(&format!("hl.unbind({})", lua_str(&keys))).await;
    }
    let mut applied = Vec::new();
    for bind in s.get("keybinds").as_array().cloned().unwrap_or_default() {
        if bind["enabled"].as_bool() == Some(false) {
            continue;
        }
        let Some((keys, lua)) = bind_lua(&bind) else { continue };
        match eval(&lua).await {
            Ok(()) => applied.push(keys),
            Err(e) => errors.push(format!("{keys}: {e}")),
        }
    }
    *h.applied_binds.lock().unwrap() = applied;

    let layouts: Vec<String> = s.get("keyboard.layouts").as_array().map(|a| a.iter().filter_map(|v| v.as_str().map(String::from)).collect()).unwrap_or_default();
    if !layouts.is_empty() {
        // Entries are "layout" or "layout(variant)".
        let (names, variants): (Vec<String>, Vec<String>) = layouts
            .iter()
            .map(|l| match l.split_once('(') {
                Some((name, variant)) => (name.trim().to_string(), variant.trim_end_matches(')').to_string()),
                None => (l.trim().to_string(), String::new()),
            })
            .unzip();
        let lua = format!(
            "hl.config({{ input = {{ kb_layout = {}, kb_variant = {}, kb_options = {} }} }})",
            lua_str(&names.join(",")),
            lua_str(&variants.join(",")),
            lua_str(&s.str("keyboard.options"))
        );
        if let Err(e) = eval(&lua).await {
            errors.push(format!("keyboard layouts: {e}"));
        }
        h.kb_dirty.notify_one();
    }

    if startup {
        let saved = s.get("monitors");
        if saved.as_array().is_some_and(|a| !a.is_empty()) {
            if let Err(e) = apply_monitors(&saved, false).await {
                errors.push(format!("monitors: {e}"));
            }
        }
    }
    if errors.is_empty() {
        Ok(())
    } else {
        bail!("{}", errors.join("; "))
    }
}

async fn apply_monitors(layout: &Value, persist: bool) -> Result<()> {
    let connected = query("monitors").await?;
    let connected: Vec<&str> = connected.as_array().map(|a| a.iter().filter_map(|m| m["name"].as_str()).collect()).unwrap_or_default();
    let mut applied = Vec::new();
    for m in layout.as_array().ok_or_else(|| anyhow!("monitors must be a list"))? {
        let name = m.str("name")?;
        if !connected.contains(&name) {
            continue;
        }
        let mode = format!("{}x{}@{}", m.int("width")?, m.int("height")?, m.num("refreshRate")?);
        let position = format!("{}x{}", m.int("x")?, m.int("y")?);
        let lua = format!(
            "hl.monitor({{ output = {}, mode = {}, position = {}, scale = {}, transform = {} }})",
            lua_str(name),
            lua_str(&mode),
            lua_str(&position),
            m.num_or("scale", 1.0),
            m.num_or("transform", 0.0) as i64
        );
        eval(&lua).await?;
        applied.push(name.to_string());
    }
    if persist {
        d().settings.set("monitors", layout.clone())?;
        d().hub.toast("ok", "Displays", &format!("Applied layout for {}", applied.join(", ")));
        // The wallpaper daemon needs a moment to pick up the new mode before it is re-rendered.
        tokio::spawn(async {
            tokio::time::sleep(Duration::from_millis(800)).await;
            super::wallpaper::reapply().await;
        });
    }
    d().hypr.dirty.notify_one();
    Ok(())
}

/// True when this is the daemon's first start in the current compositor
/// session, as opposed to a restart of the daemon within it.
pub fn fresh_session() -> bool {
    static FRESH: std::sync::OnceLock<bool> = std::sync::OnceLock::new();
    *FRESH.get_or_init(|| {
        let marker = util::dirs().run.join(format!("started-{}", util::hash_str(&instance().unwrap_or_default())));
        if marker.exists() {
            return false;
        }
        let _ = std::fs::write(&marker, b"");
        true
    })
}

/// Startup commands run once per compositor session, not once per daemon start.
async fn run_startup_commands() {
    if !fresh_session() {
        return;
    }
    for entry in d().settings.get("startup").as_array().cloned().unwrap_or_default() {
        let command = entry["command"].as_str().or(entry.as_str()).unwrap_or("").trim().to_string();
        if !command.is_empty() && entry["enabled"].as_bool() != Some(false) {
            if let Err(e) = exec(&command).await {
                log!("startup command '{command}': {e:#}");
            }
        }
    }
}

/// Set the window border colours (called by the theme when the palette changes).
pub async fn set_border(active_a: &str, active_b: &str, inactive: &str) {
    if instance().is_none() {
        return;
    }
    let rgb = |hex: &str| format!("rgb({})", hex.trim_start_matches('#'));
    let lua = format!(
        "hl.config({{ general = {{ col = {{ active_border = {{ colors = {{ {}, {} }}, angle = 45 }}, inactive_border = {} }} }} }})",
        lua_str(&rgb(active_a)),
        lua_str(&rgb(active_b)),
        lua_str(&rgb(inactive))
    );
    if let Err(e) = eval(&lua).await {
        log!("border colours: {e:#}");
    }
}

pub async fn call(name: &str, p: &Value) -> Result<Value> {
    match name {
        "workspace" => {
            d().hub.emit("ui", &json!({ "action": "close" }));
            dispatch(&format!("hl.dsp.focus({{ workspace = {} }})", p.int("id")?)).await?;
        }
        "moveToWorkspace" => dispatch(&format!("hl.dsp.window.move({{ workspace = {} }})", p.int("id")?)).await?,
        "dispatch" => dispatch(p.str("lua")?).await?,
        "eval" => eval(p.str("lua")?).await?,
        "exec" => exec(p.str("command")?).await?,
        "nextLayout" => check(request("switchxkblayout main next").await?)?,
        "binds" => return binds().await,
        "clients" => return query("clients").await,
        "reload" => check(request("reload").await?)?,
        "applyMonitors" => apply_monitors(p.get("monitors").ok_or_else(|| anyhow!("missing 'monitors'"))?, true).await?,
        "applySettings" => apply_settings(false).await?,
        _ => bail!("unknown method hypr.{name}"),
    }
    Ok(Value::Null)
}
