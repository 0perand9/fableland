//! Installed applications (`apps` topic): desktop entries parsed per the XDG
//! spec, launch counts for ranking, and class → name/icon lookup for other modules.

use crate::util::Params;
use crate::{d, util};
use anyhow::{anyhow, bail, Result};
use serde_json::{json, Value};
use std::collections::{HashMap, HashSet};
use std::path::{Path, PathBuf};
use std::sync::Mutex;

#[derive(Default)]
pub struct Apps {
    list: Mutex<Vec<Value>>,
    /// Lower-cased window class / desktop id → (display name, icon).
    by_class: Mutex<HashMap<String, (String, String)>>,
    /// Changes when any application directory changes.
    signature: Mutex<String>,
}

fn usage_file() -> PathBuf {
    util::dirs().state.join("app-usage.json")
}

/// Application directories in precedence order (user first).
fn app_dirs() -> Vec<PathBuf> {
    let data_home = std::env::var("XDG_DATA_HOME").ok().filter(|s| !s.is_empty()).map(PathBuf::from).unwrap_or_else(|| util::home().join(".local/share"));
    let data_dirs = std::env::var("XDG_DATA_DIRS").ok().filter(|s| !s.is_empty()).unwrap_or_else(|| "/usr/local/share:/usr/share".into());
    let mut dirs = vec![data_home.join("applications")];
    dirs.extend(data_dirs.split(':').filter(|s| !s.is_empty()).map(|s| Path::new(s).join("applications")));
    let mut seen = HashSet::new();
    dirs.retain(|p| p.is_dir() && seen.insert(p.canonicalize().unwrap_or_else(|_| p.clone())));
    dirs
}

fn desktop_files(dir: &Path, root: &Path, out: &mut Vec<(String, PathBuf)>) {
    let Ok(rd) = std::fs::read_dir(dir) else { return };
    for entry in rd.flatten() {
        let path = entry.path();
        if path.is_dir() {
            desktop_files(&path, root, out);
        } else if path.extension().is_some_and(|e| e == "desktop") {
            // The desktop file ID: path below the applications dir with '/' turned into '-'.
            if let Ok(rel) = path.strip_prefix(root) {
                out.push((rel.to_string_lossy().replace('/', "-"), path));
            }
        }
    }
}

fn parse(path: &Path) -> Option<HashMap<String, String>> {
    let text = std::fs::read_to_string(path).ok()?;
    let mut fields = HashMap::new();
    let mut in_entry = false;
    for line in text.lines() {
        let line = line.trim();
        if line.starts_with('[') {
            in_entry = line == "[Desktop Entry]";
            continue;
        }
        if !in_entry || line.starts_with('#') {
            continue;
        }
        if let Some((key, value)) = line.split_once('=') {
            // Localised variants (Name[de]) are skipped; the first plain key wins.
            let key = key.trim();
            if !key.contains('[') {
                fields.entry(key.to_string()).or_insert_with(|| value.trim().to_string());
            }
        }
    }
    Some(fields)
}

/// Strip the `%f`-style field codes from an Exec line.
fn clean_exec(exec: &str) -> String {
    let mut out = String::with_capacity(exec.len());
    let mut chars = exec.chars();
    while let Some(c) = chars.next() {
        if c == '%' {
            if chars.next() == Some('%') {
                out.push('%');
            }
        } else {
            out.push(c);
        }
    }
    out.split_whitespace().collect::<Vec<_>>().join(" ")
}

fn scan() {
    let a = &d().apps;
    let desktop = std::env::var("XDG_CURRENT_DESKTOP").unwrap_or_else(|_| "Hyprland".into());
    let on_desktop = |list: &str| list.split(';').any(|e| desktop.split(':').any(|d| d.eq_ignore_ascii_case(e)));
    let usage = util::read_json(&usage_file()).unwrap_or(Value::Null);

    let mut seen = HashSet::new();
    let mut list = Vec::new();
    let mut classes = HashMap::new();
    for dir in app_dirs() {
        let mut files = Vec::new();
        desktop_files(&dir, &dir, &mut files);
        for (id, path) in files {
            // An entry in an earlier directory shadows same-named ones later on, even if hidden.
            if !seen.insert(id.clone()) {
                continue;
            }
            let Some(f) = parse(&path) else { continue };
            let get = |k: &str| f.get(k).cloned().unwrap_or_default();
            let (name, exec, icon) = (get("Name"), get("Exec"), get("Icon"));
            if name.is_empty() || f.get("Type").is_some_and(|t| t != "Application") {
                continue;
            }
            let stem = id.trim_end_matches(".desktop").to_lowercase();
            for key in [stem.clone(), stem.rsplit('.').next().unwrap_or("").to_string(), get("StartupWMClass").to_lowercase()] {
                if !key.is_empty() {
                    classes.entry(key).or_insert_with(|| (name.clone(), icon.clone()));
                }
            }
            let hidden = get("Hidden") == "true" || get("NoDisplay") == "true";
            let wrong_desktop = f.get("OnlyShowIn").is_some_and(|l| !on_desktop(l)) || f.get("NotShowIn").is_some_and(|l| on_desktop(l));
            let missing = f.get("TryExec").is_some_and(|t| !util::which(t));
            if hidden || wrong_desktop || missing || exec.is_empty() {
                continue;
            }
            list.push(json!({
                "id": id, "name": name, "generic": get("GenericName"), "comment": get("Comment"),
                "exec": clean_exec(&exec), "icon": icon, "terminal": get("Terminal") == "true",
                "keywords": get("Keywords").replace(';', " "),
                "uses": usage[&id]["count"].as_u64().unwrap_or(0), "lastUsed": usage[&id]["last"].as_u64().unwrap_or(0),
            }));
        }
    }
    list.sort_by_key(|a| a["name"].as_str().unwrap_or("").to_lowercase());
    *a.by_class.lock().unwrap() = classes;
    *a.list.lock().unwrap() = list.clone();
    d().hub.publish("apps", &list);
}

fn signature() -> String {
    app_dirs().iter().map(|p| format!("{}:{};", p.canonicalize().unwrap_or_else(|_| p.clone()).display(), util::mtime_s(p))).collect()
}

fn rescan_if_changed() {
    let sig = signature();
    let mut current = d().apps.signature.lock().unwrap();
    if *current != sig {
        *current = sig;
        drop(current);
        scan();
    }
}

impl Apps {
    /// Human name and icon for a window class, if a desktop entry matches it.
    pub fn resolve(&self, class: &str) -> Option<(String, String)> {
        let map = self.by_class.lock().unwrap();
        let lower = class.to_lowercase();
        map.get(&lower).or_else(|| map.get(lower.rsplit('.').next().unwrap_or(""))).cloned()
    }

    /// The icon of the application that best matches one of `names` (an icon
    /// name, a binary, an application name — whatever a client reported).
    /// Falls back to an entry whose id merely starts with the name, so the
    /// "zen" audio stream finds "zen-beta.desktop".
    pub fn icon_for(&self, names: &[&str]) -> Option<String> {
        let names: Vec<String> = names.iter().filter(|n| !n.is_empty()).map(|n| n.trim_start_matches('.').trim_end_matches("-wrapped").to_lowercase()).collect();
        if let Some((_, icon)) = names.iter().find_map(|n| self.resolve(n)) {
            return Some(icon);
        }
        let map = self.by_class.lock().unwrap();
        names.iter().find_map(|n| map.iter().filter(|(class, _)| class.strip_prefix(n.as_str()).is_some_and(|rest| rest.starts_with(['-', '_', '.']))).min_by_key(|(class, _)| class.len()).map(|(_, (_, icon))| icon.clone()))
    }
}

pub async fn run() -> Result<()> {
    tokio::task::spawn_blocking(rescan_if_changed).await?;
    Ok(())
}

pub async fn call(name: &str, p: &Value) -> Result<Value> {
    match name {
        // Called when the launcher opens: cheap unless something was (un)installed.
        "refresh" => tokio::task::spawn_blocking(rescan_if_changed).await?,
        "launch" => {
            let id = p.str("id")?;
            let app = d().apps.list.lock().unwrap().iter().find(|a| a["id"].as_str() == Some(id)).cloned().ok_or_else(|| anyhow!("unknown application '{id}'"))?;
            let exec = app["exec"].as_str().unwrap_or("");
            let command = if app["terminal"] == true { format!("{} -e {exec}", d().settings.str("terminal")) } else { exec.to_string() };
            super::hypr::exec(&command).await?;

            let mut usage = util::read_json(&usage_file()).filter(Value::is_object).unwrap_or_else(|| json!({}));
            usage[id] = json!({ "count": usage[id]["count"].as_u64().unwrap_or(0) + 1, "last": util::now_s() });
            let _ = util::write_json(&usage_file(), &usage);
            tokio::task::spawn_blocking(scan).await?;
        }
        "run" => super::hypr::exec(p.str("command")?).await?,
        _ => bail!("unknown method apps.{name}"),
    }
    Ok(Value::Null)
}
