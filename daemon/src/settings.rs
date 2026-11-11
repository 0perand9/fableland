//! Settings: one in-memory copy, one writer, three layers.
//!
//!   defaults        [`defaults`], below
//!   settings.json   what the user changed, in the Settings popup or by hand
//!   managed.json    what a system configuration (the Nix module, say) fixes:
//!                   read only, and it wins — these keys cannot be changed here
//!
//! Both files are in `~/.config/fableland` and hold only what they set. Modules
//! read with dotted paths (`settings.str("wallpaper.dir")`) and react to edits
//! by awaiting [`Settings::changes`].

use crate::{d, log, util};
use anyhow::{anyhow, bail, Result};
use serde_json::{json, Map, Value};
use std::path::{Path, PathBuf};
use std::sync::Mutex;
use tokio::sync::watch;

pub fn defaults() -> Value {
    json!({
        "uiScale": 1.0,
        "workspaceCount": 8,
        "showHelpIcon": true,
        "openGuideAtStartup": false,
        "terminal": "kitty",
        "wallpaper": {
            "dir": "~/Pictures/Wallpapers",
            "scheme": "scheme-vibrant",
            "mode": "dark",
            "transition": "random"
        },
        "weather": {
            "provider": "open-meteo",
            "unit": "metric",
            "city": "",
            "lat": null,
            "lon": null,
            "owmKey": "",
            "owmCityId": ""
        },
        "keyboard": { "layouts": [], "options": "" },
        "keybinds": [],
        "startup": [],
        "monitors": [],
        "notifications": { "dnd": false, "timeoutMs": 5000 },
        "focus": { "idleMinutes": 5, "countSystem": false },
        "lock": { "hidePassword": true, "revealMs": 600, "pamConfig": "" },
        "idle": { "lockMinutes": 0, "screenOffMinutes": 0 },
        "capture": {
            "dir": "~/Pictures/Screenshots",
            "videoDir": "~/Videos/Recordings",
            "editor": "satty",
            "audio": "desktop"
        },
        "clipboard": { "autoPaste": false },
        "diary": { "dir": "~/Documents/Diary", "obsidianVault": "" },
        "schedule": { "command": "" },
        "updates": { "flakeDir": "", "command": "", "intervalHours": 6 },
        "movies": { "openWith": "https://www.justwatch.com/us/search?q={title}" },
        "launcher": { "searchUrl": "https://duckduckgo.com/?q={query}" },
        "backdrop": { "style": "contours", "strength": 100, "speed": 100, "reactive": true },
        "osd": true,
        "sounds": true,
        // See features.rs.
        "features": crate::features::names().map(|name| (name.to_string(), json!(true))).collect::<Map<_, _>>()
    })
}

pub struct Settings {
    /// The defaults with settings.json on top: what the user chose.
    user: Mutex<Value>,
    /// managed.json: nothing but the keys it fixes.
    managed: Mutex<Value>,
    /// `user` with `managed` on top: what applies.
    value: Mutex<Value>,
    /// What both files looked like when they were last read.
    seen: Mutex<[Stamp; 2]>,
    version: watch::Sender<u64>,
}

impl Default for Settings {
    fn default() -> Self {
        Settings { user: Mutex::new(defaults()), managed: Mutex::new(json!({})), value: Mutex::new(defaults()), seen: Mutex::default(), version: watch::channel(0).0 }
    }
}

fn file() -> PathBuf {
    util::dirs().config.join("settings.json")
}

fn managed_file() -> PathBuf {
    util::dirs().config.join("managed.json")
}

/// Tells one state of a file from the next. A file put in place by a system
/// configuration is a link whose target has no meaningful time: there, what
/// changes is where the link leads.
type Stamp = (PathBuf, u64);

fn stamp(path: &Path) -> Stamp {
    (std::fs::canonicalize(path).unwrap_or_default(), util::mtime_s(path))
}

/// A settings file: None when there is none. One that cannot be read counts for nothing until it is repaired.
fn read(path: &Path) -> Option<Value> {
    let raw = std::fs::read(path).ok()?;
    match serde_json::from_slice::<Value>(&raw) {
        Ok(tree) if tree.is_object() => Some(tree),
        Ok(_) => Some(invalid(path, "it is not an object")),
        Err(e) => Some(invalid(path, &e.to_string())),
    }
}

fn invalid(path: &Path, why: &str) -> Value {
    let name = path.file_name().unwrap_or_default().to_string_lossy();
    log!("{name} is invalid ({why}); ignoring it until it is fixed");
    d().hub.toast("error", "Settings", &format!("{name} is invalid: {why}"));
    json!({})
}

/// Overlay `patch` onto `base`, recursing into objects. Arrays are replaced whole.
fn merge(base: &mut Value, patch: &Value) {
    match (base, patch) {
        (Value::Object(b), Value::Object(p)) => {
            for (k, v) in p {
                merge(b.entry(k.clone()).or_insert(Value::Null), v);
            }
        }
        (b, p) => *b = p.clone(),
    }
}

/// The parts of `current` that differ from `base`: this is what gets written to disk.
fn diff(base: &Value, current: &Value) -> Option<Value> {
    match (base, current) {
        (Value::Object(b), Value::Object(c)) => {
            let mut out = Map::new();
            for (k, v) in c {
                match b.get(k) {
                    Some(bv) => {
                        if let Some(dv) = diff(bv, v) {
                            out.insert(k.clone(), dv);
                        }
                    }
                    None => {
                        out.insert(k.clone(), v.clone());
                    }
                }
            }
            (!out.is_empty()).then_some(Value::Object(out))
        }
        (b, c) => (b != c).then(|| c.clone()),
    }
}

/// Dotted paths of the values in `tree`: objects are walked, anything else is a value.
fn leaves(tree: &Value, prefix: &str, out: &mut Vec<String>) {
    match tree.as_object() {
        Some(map) => {
            for (key, value) in map {
                leaves(value, &if prefix.is_empty() { key.clone() } else { format!("{prefix}.{key}") }, out);
            }
        }
        None => out.push(prefix.to_string()),
    }
}

impl Settings {
    pub fn load(&self) {
        let mut user = defaults();
        match read(&file()) {
            // Never overwrite a file the user may want to repair by hand: an invalid one reads as empty.
            Some(changed) => merge(&mut user, &changed),
            None => first_run(&mut user),
        }
        *self.user.lock().unwrap() = user;
        *self.managed.lock().unwrap() = read(&managed_file()).unwrap_or_else(|| json!({}));
        *self.seen.lock().unwrap() = [stamp(&file()), stamp(&managed_file())];
        self.announce();
    }

    /// Work out what applies and tell everyone.
    fn announce(&self) {
        let managed = self.managed.lock().unwrap().clone();
        let mut value = self.user.lock().unwrap().clone();
        merge(&mut value, &managed);
        d().hub.publish("settings", &value);
        d().hub.publish("managed", &managed);
        *self.value.lock().unwrap() = value;
        self.version.send_modify(|v| *v += 1);
    }

    fn save(&self) -> Result<()> {
        let on_disk = diff(&defaults(), &self.user.lock().unwrap()).unwrap_or_else(|| json!({}));
        util::write_json(&file(), &on_disk)?;
        self.seen.lock().unwrap()[0] = stamp(&file());
        Ok(())
    }

    /// Fails when managed.json fixes the value at `path`, or one that `path` is a part of.
    fn check_free(&self, path: &str) -> Result<()> {
        let managed = self.managed.lock().unwrap();
        let mut at = &*managed;
        for part in path.split('.') {
            match at.as_object() {
                Some(map) => match map.get(part) {
                    Some(inner) => at = inner,
                    None => return Ok(()),
                },
                None => break,
            }
        }
        // An object here only fixes some of what is inside: those parts stay as they are.
        if at.is_object() {
            return Ok(());
        }
        bail!("{path} is set by the system configuration (managed.json) and cannot be changed here")
    }

    /// Value at a dotted path such as `"wallpaper.dir"` (Null when absent).
    pub fn get(&self, path: &str) -> Value {
        let v = self.value.lock().unwrap();
        let mut cur = &*v;
        for part in path.split('.') {
            match cur.get(part) {
                Some(next) => cur = next,
                None => return Value::Null,
            }
        }
        cur.clone()
    }

    pub fn str(&self, path: &str) -> String {
        self.get(path).as_str().unwrap_or("").to_string()
    }

    pub fn num(&self, path: &str) -> f64 {
        self.get(path).as_f64().unwrap_or(0.0)
    }

    pub fn flag(&self, path: &str) -> bool {
        self.get(path).as_bool().unwrap_or(false)
    }

    pub fn set(&self, path: &str, new: Value) -> Result<()> {
        self.check_free(path)?;
        {
            let mut v = self.user.lock().unwrap();
            let mut cur = &mut *v;
            let mut parts = path.split('.').peekable();
            while let Some(part) = parts.next() {
                if !cur.is_object() {
                    *cur = json!({});
                }
                let obj = cur.as_object_mut().ok_or_else(|| anyhow!("bad settings path '{path}'"))?;
                if parts.peek().is_none() {
                    obj.insert(part.to_string(), new);
                    break;
                }
                cur = obj.entry(part.to_string()).or_insert_with(|| json!({}));
            }
        }
        self.save()?;
        self.announce();
        Ok(())
    }

    pub fn patch(&self, patch: &Value) -> Result<()> {
        let mut paths = Vec::new();
        leaves(patch, "", &mut paths);
        for path in &paths {
            self.check_free(path)?;
        }
        merge(&mut self.user.lock().unwrap(), patch);
        self.save()?;
        self.announce();
        Ok(())
    }

    /// Back to the defaults (and to whatever managed.json fixes).
    fn reset(&self) -> Result<()> {
        *self.user.lock().unwrap() = defaults();
        self.save()?;
        self.announce();
        Ok(())
    }

    /// A receiver that fires after every settings change.
    pub fn changes(&self) -> watch::Receiver<u64> {
        self.version.subscribe()
    }
}

/// Carry over what is worth keeping from the previous shell on the very first start.
fn first_run(settings: &mut Value) {
    let old_env = util::home().join(".config/hypr/scripts/quickshell/calendar/.env");
    let Ok(text) = std::fs::read_to_string(old_env) else { return };
    let mut weather = Map::new();
    for line in text.lines() {
        let Some((key, raw)) = line.split_once('=') else { continue };
        let val = raw.trim().trim_matches(|c| c == '\'' || c == '"').to_string();
        if val.is_empty() || val == "Skipped" {
            continue;
        }
        match key.trim() {
            "OPENWEATHER_KEY" if val != "OPENWEATHER_KEY" => {
                weather.insert("owmKey".into(), json!(val));
                weather.insert("provider".into(), json!("openweathermap"));
            }
            "OPENWEATHER_CITY_ID" => {
                weather.insert("owmCityId".into(), json!(val));
            }
            "OPENWEATHER_UNIT" => {
                weather.insert("unit".into(), json!(val));
            }
            _ => {}
        }
    }
    if weather.contains_key("owmKey") && weather.contains_key("owmCityId") {
        log!("imported weather configuration from the previous shell");
        merge(settings, &json!({ "weather": weather }));
        let on_disk = diff(&defaults(), settings).unwrap_or_else(|| json!({}));
        let _ = util::write_json(&file(), &on_disk);
    }
}

/// Pick up edits made to settings.json by hand, and a managed.json that was replaced.
pub async fn run() -> Result<()> {
    loop {
        tokio::time::sleep(std::time::Duration::from_secs(3)).await;
        let s = &d().settings;
        if *s.seen.lock().unwrap() != [stamp(&file()), stamp(&managed_file())] {
            log!("the settings changed on disk, reloading");
            s.load();
        }
    }
}

pub async fn call(name: &str, p: &Value) -> Result<Value> {
    use util::Params;
    let s = &d().settings;
    match name {
        "get" => Ok(s.get(p.str_or("key", ""))),
        "set" => {
            s.set(p.str("key")?, p.get("value").cloned().unwrap_or(Value::Null))?;
            Ok(Value::Null)
        }
        "patch" => {
            s.patch(p.get("patch").ok_or_else(|| anyhow!("missing 'patch'"))?)?;
            Ok(Value::Null)
        }
        "reset" => {
            s.reset()?;
            Ok(Value::Null)
        }
        _ => Err(anyhow!("unknown method settings.{name}")),
    }
}
