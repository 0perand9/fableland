//! Small services that do not deserve a module of their own: system information,
//! sounds, opening links, directory completion, the diary, the optional schedule
//! feed and the keyboard layout catalogue.

use crate::util::Params;
use crate::{d, log, util};
use anyhow::{anyhow, bail, Result};
use chrono::{Local, NaiveDate};
use serde_json::{json, Value};
use std::path::PathBuf;
use std::time::Duration;

/// Play one of the bundled sounds (connect, disconnect, power_on, power_off, switch, alarm).
pub fn play_sound(name: &str) {
    if !d().settings.flag("sounds") || crate::options().read_only {
        return;
    }
    let Some(dir) = super::ui::assets_dir() else { return };
    let Some(file) = ["wav", "oga"].iter().map(|ext| dir.join(format!("sounds/{name}.{ext}"))).find(|p| p.exists()) else { return };
    if let Some(player) = util::first_installed(&["pw-play", "paplay"]) {
        util::spawn_detached(player, &[&file.to_string_lossy()]);
    }
}

async fn sysinfo() -> Value {
    let read = |p: &str| std::fs::read_to_string(p).unwrap_or_default();
    let os = read("/etc/os-release").lines().find_map(|l| l.strip_prefix("PRETTY_NAME=").map(|v| v.trim_matches('"').to_string())).unwrap_or_default();
    let cpu = read("/proc/cpuinfo").lines().find(|l| l.starts_with("model name")).and_then(|l| l.split_once(':')).map(|(_, v)| v.trim().to_string()).unwrap_or_default();
    let gpu = if util::which("nvidia-smi") {
        util::run("nvidia-smi", &["--query-gpu=name", "--format=csv,noheader"]).await.map(|s| s.lines().next().unwrap_or("").trim().to_string()).unwrap_or_default()
    } else if util::which("lspci") {
        util::run("lspci", &[]).await.ok().and_then(|out| out.lines().filter(|l| l.contains("VGA") || l.contains("3D") || l.contains("Display")).next_back().and_then(|l| l.split(": ").nth(1).map(String::from))).unwrap_or_default()
    } else {
        String::new()
    };
    let avatar = [".face.icon", ".face"].iter().map(|f| util::home().join(f)).find(|p| p.exists()).and_then(|p| p.canonicalize().ok()).map(|p| p.to_string_lossy().into_owned()).unwrap_or_default();
    let hyprland = super::hypr::request("version").await.ok().and_then(|v| v.lines().next().map(|l| l.split(" built").next().unwrap_or(l).to_string())).unwrap_or_default();
    json!({
        "user": std::env::var("USER").unwrap_or_default(), "host": super::power::hostname(), "os": os,
        "kernel": read("/proc/sys/kernel/osrelease").trim(), "cpu": cpu, "gpu": gpu, "avatar": avatar, "compositor": hyprland,
        "version": env!("CARGO_PKG_VERSION"),
    })
}

fn diary_dir() -> PathBuf {
    util::expand(&d().settings.str("diary.dir"))
}

fn diary_file(date: NaiveDate) -> PathBuf {
    diary_dir().join(date.format("%Y").to_string()).join(format!("{}.md", date.format("%Y-%m-%d")))
}

fn image_dir() -> PathBuf {
    let dir = util::dirs().cache.join("images");
    util::ensure_dir(&dir);
    dir
}

/// Fetch a picture from the web into the cache and return its path. Anything
/// that is not JPEG or PNG (posters are often WebP) is converted, so the UI
/// can show it without extra Qt image plugins — and shows it instantly next time.
async fn cached_image(url: &str) -> Result<String> {
    if !(url.starts_with("https://") || url.starts_with("http://")) {
        bail!("not a web address: {url}");
    }
    let stem = util::hash_str(url);
    if let Some(hit) = ["jpg", "png"].iter().map(|ext| image_dir().join(format!("{stem}.{ext}"))).find(|p| p.exists()) {
        return Ok(hit.to_string_lossy().into_owned());
    }
    let url = url.to_string();
    tokio::task::spawn_blocking(move || -> Result<String> {
        use std::io::Read;
        let mut data = Vec::new();
        ureq::get(&url).timeout(Duration::from_secs(15)).call()?.into_reader().take(12 << 20).read_to_end(&mut data)?;
        let (ext, bytes) = match image::guess_format(&data)? {
            image::ImageFormat::Jpeg => ("jpg", data),
            image::ImageFormat::Png => ("png", data),
            _ => {
                let mut jpeg = Vec::new();
                image::load_from_memory(&data)?.to_rgb8().write_to(&mut std::io::Cursor::new(&mut jpeg), image::ImageFormat::Jpeg)?;
                ("jpg", jpeg)
            }
        };
        let path = image_dir().join(format!("{stem}.{ext}"));
        util::write_atomic(&path, &bytes)?;
        Ok(path.to_string_lossy().into_owned())
    })
    .await?
}

/// Cached pictures older than a month are dropped; whatever is still wanted is fetched again.
fn prune_images() {
    let Ok(entries) = std::fs::read_dir(image_dir()) else { return };
    let cutoff = util::now_s().saturating_sub(30 * 86400);
    for entry in entries.flatten() {
        if util::mtime_s(&entry.path()) < cutoff {
            let _ = std::fs::remove_file(entry.path());
        }
    }
}

/// Run the user's schedule command (if any) and publish what it prints.
async fn schedule_loop() {
    let s = &d().settings;
    let mut rx = s.changes();
    loop {
        let command = s.str("schedule.command");
        if command.is_empty() {
            d().hub.publish("schedule", &json!({ "available": false }));
        } else {
            match tokio::time::timeout(Duration::from_secs(120), util::run("sh", &["-c", &command])).await {
                Ok(Ok(out)) => match serde_json::from_str::<Value>(out.trim()) {
                    Ok(mut data) if data.is_object() => {
                        data["available"] = json!(true);
                        d().hub.publish("schedule", &data);
                    }
                    _ => log!("schedule command did not print a JSON object"),
                },
                Ok(Err(e)) => log!("schedule command: {e:#}"),
                Err(_) => log!("schedule command timed out"),
            }
        }
        tokio::select! {
            _ = tokio::time::sleep(Duration::from_secs(600)) => {}
            _ = async { while rx.changed().await.is_ok() { if s.str("schedule.command") != command { break; } } } => {}
        }
    }
}

/// Every keyboard layout and variant known to xkb: [{id: "us(intl)", name: "English (US, intl.)"}].
async fn xkb_layouts() -> Result<Value> {
    static CACHE: std::sync::OnceLock<Value> = std::sync::OnceLock::new();
    if let Some(v) = CACHE.get() {
        return Ok(v.clone());
    }
    let out = util::run("xkbcli", &["list"]).await.map_err(|_| anyhow!("xkbcli (libxkbcommon tools) is needed to list keyboard layouts"))?;
    let unquote = |s: &str| s.trim().trim_matches('\'').trim_matches('"').to_string();
    let (mut list, mut in_layouts) = (Vec::new(), false);
    let (mut layout, mut variant) = (String::new(), String::new());
    for line in out.lines() {
        if !line.starts_with(' ') && !line.starts_with('-') {
            in_layouts = line.starts_with("layouts:");
            continue;
        }
        if !in_layouts {
            continue;
        }
        if let Some(v) = line.strip_prefix("- layout:") {
            layout = unquote(v);
            variant.clear();
        } else if let Some(v) = line.trim_start().strip_prefix("variant:") {
            variant = unquote(v);
        } else if let Some(v) = line.trim_start().strip_prefix("description:") {
            let id = if variant.is_empty() { layout.clone() } else { format!("{layout}({variant})") };
            list.push(json!({ "id": id, "name": unquote(v) }));
        }
    }
    let v = json!(list);
    let _ = CACHE.set(v.clone());
    Ok(v)
}

pub async fn run() -> Result<()> {
    d().hub.publish("sysinfo", &sysinfo().await);
    tokio::task::spawn_blocking(prune_images);
    schedule_loop().await;
    Ok(())
}

pub async fn call(name: &str, p: &Value) -> Result<Value> {
    match name {
        "open" => util::spawn_detached("xdg-open", &[p.str("target")?]),
        "sound" => play_sound(p.str("name")?),
        "image" => return Ok(json!(cached_image(p.str("url")?).await?)),
        "sysinfo" => return Ok(sysinfo().await),
        "xkbLayouts" => return xkb_layouts().await,
        // Directory completion for path fields. Pure filesystem listing: nothing is executed.
        "suggestDirs" => {
            let typed = p.str("prefix")?;
            let full = util::expand(typed);
            let (parent, partial) = if typed.ends_with('/') { (full.clone(), String::new()) } else { (full.parent().map(PathBuf::from).unwrap_or_default(), full.file_name().map(|n| n.to_string_lossy().to_lowercase()).unwrap_or_default()) };
            let mut found: Vec<String> = std::fs::read_dir(&parent)
                .map(|rd| {
                    rd.flatten()
                        .filter(|e| e.path().is_dir())
                        .filter_map(|e| e.file_name().into_string().ok())
                        .filter(|n| n.to_lowercase().starts_with(&partial) && (partial.starts_with('.') || !n.starts_with('.')))
                        .map(|n| format!("{}/", parent.join(n).display()))
                        .collect()
                })
                .unwrap_or_default();
            found.sort();
            found.truncate(p.num_or("limit", 6.0) as usize);
            return Ok(json!(found));
        }
        "diaryOpen" => {
            let date = match p.get("date").and_then(Value::as_str) {
                Some(s) => NaiveDate::parse_from_str(s, "%Y-%m-%d").map_err(|_| anyhow!("date must be YYYY-MM-DD"))?,
                None => Local::now().date_naive(),
            };
            let file = diary_file(date);
            if !file.exists() {
                util::write_atomic(&file, format!("# {}\n\n", date.format("%A, %-d %B %Y")).as_bytes())?;
            }
            let vault = d().settings.str("diary.obsidianVault");
            let target = match file.strip_prefix(diary_dir()) {
                // Inside an Obsidian vault the note opens in Obsidian rather than a text editor.
                Ok(rel) if !vault.is_empty() => format!("obsidian://open?vault={vault}&file={}", rel.with_extension("").display()),
                _ => file.to_string_lossy().into_owned(),
            };
            util::spawn_detached("xdg-open", &[&target]);
        }
        // Days of a month ("YYYY-MM") that have a diary entry.
        "diaryDays" => {
            let month = p.str("month")?;
            let dir = diary_dir().join(month.get(..4).unwrap_or(""));
            let days: Vec<u32> = std::fs::read_dir(dir)
                .map(|rd| rd.flatten().filter_map(|e| e.file_name().into_string().ok()).filter(|n| n.starts_with(month) && n.ends_with(".md")).filter_map(|n| n.get(8..10).and_then(|d| d.parse().ok())).collect())
                .unwrap_or_default();
            return Ok(json!(days));
        }
        _ => bail!("unknown method misc.{name}"),
    }
    Ok(Value::Null)
}
