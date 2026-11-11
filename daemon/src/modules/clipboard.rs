//! Clipboard history, backed by `cliphist`. The daemon also owns the two
//! `wl-paste --watch` processes that feed the history.

use crate::util::Params;
use crate::{d, log, util};
use anyhow::{anyhow, bail, Result};
use serde_json::{json, Value};
use std::collections::HashMap;
use std::path::PathBuf;
use std::process::Stdio;
use std::sync::Mutex;

/// id → the exact `cliphist list` line, which `cliphist delete` needs back verbatim.
static LINES: Mutex<Option<HashMap<String, String>>> = Mutex::new(None);

fn image_dir() -> PathBuf {
    let dir = util::dirs().cache.join("clipboard");
    util::ensure_dir(&dir);
    dir
}

/// "[[ binary data 153 KiB png 1920x1080 ]]" → ("png", "153 KiB · 1920x1080").
fn binary_meta(preview: &str) -> Option<(String, String)> {
    let inner = preview.trim().strip_prefix("[[ binary data ")?.strip_suffix(" ]]")?;
    let parts: Vec<&str> = inner.split_whitespace().collect();
    let ext = parts.get(2)?.to_string();
    Some((ext, format!("{} {} · {}", parts.first()?, parts.get(1)?, parts.get(3).unwrap_or(&""))))
}

pub async fn run() -> Result<()> {
    if !util::which("cliphist") || !util::which("wl-paste") {
        log!("cliphist or wl-clipboard missing; clipboard history disabled");
        return Ok(());
    }
    // Leave existing watchers alone (e.g. started by the compositor config).
    if crate::options().read_only || util::cmdline_running(&["wl-paste", "cliphist store"]) {
        return Ok(());
    }
    let mut watchers = Vec::new();
    for kind in ["text", "image"] {
        let child = tokio::process::Command::new("wl-paste").args(["--type", kind, "--watch", "cliphist", "store"]).stdin(Stdio::null()).stdout(Stdio::null()).stderr(Stdio::null()).kill_on_drop(true).spawn()?;
        watchers.push(child);
    }
    // Hold the children for the daemon's lifetime; dropping them stops the watchers.
    std::future::pending::<()>().await;
    drop(watchers);
    Ok(())
}

async fn decode(id: &str) -> Result<Vec<u8>> {
    let out = tokio::process::Command::new("cliphist").args(["decode", id]).stdin(Stdio::null()).output().await?;
    if !out.status.success() {
        bail!("that clipboard entry no longer exists");
    }
    Ok(out.stdout)
}

async fn list(p: &Value) -> Result<Value> {
    let offset = p.num_or("offset", 0.0) as usize;
    let limit = p.num_or("limit", 30.0) as usize;
    let query = p.str_or("query", "").to_lowercase();
    let raw = util::run("cliphist", &["list"]).await?;

    let mut lines = HashMap::new();
    let mut entries = Vec::new();
    for line in raw.lines() {
        let Some((id, preview)) = line.split_once('\t') else { continue };
        lines.insert(id.to_string(), line.to_string());
        let binary = binary_meta(preview);
        let matches = match (&binary, query.is_empty()) {
            (_, true) => true,
            (Some(_), false) => "image".contains(&query),
            (None, false) => preview.to_lowercase().contains(&query),
        };
        if matches {
            entries.push((id.to_string(), preview.to_string(), binary));
        }
    }
    *LINES.lock().unwrap() = Some(lines);

    let total = entries.len();
    let mut items = Vec::new();
    for (id, preview, binary) in entries.into_iter().skip(offset).take(limit) {
        match binary {
            Some((ext, meta)) => {
                let file = image_dir().join(format!("{id}.{ext}"));
                if !file.exists() {
                    match decode(&id).await {
                        Ok(data) => util::write_atomic(&file, &data)?,
                        Err(_) => continue,
                    }
                }
                items.push(json!({ "id": id, "kind": "image", "image": file.to_string_lossy(), "text": meta }));
            }
            None => items.push(json!({ "id": id, "kind": "text", "text": preview })),
        }
    }

    // Keep decoded previews only for entries that still exist.
    if offset == 0 {
        if let (Some(lines), Ok(rd)) = (&*LINES.lock().unwrap(), std::fs::read_dir(image_dir())) {
            for e in rd.flatten() {
                let stem = e.path().file_stem().map(|s| s.to_string_lossy().into_owned()).unwrap_or_default();
                if !lines.contains_key(&stem) {
                    let _ = std::fs::remove_file(e.path());
                }
            }
        }
    }
    Ok(json!({ "total": total, "items": items }))
}

/// Put bytes on the clipboard. `wl-copy` stays alive to serve the selection.
pub async fn copy_bytes(data: &[u8], mime: Option<&str>) -> Result<()> {
    let args: Vec<&str> = mime.map(|m| vec!["--type", m]).unwrap_or_default();
    util::run_with_input("wl-copy", &args, data).await?;
    Ok(())
}

pub async fn call(name: &str, p: &Value) -> Result<Value> {
    if !util::which("cliphist") {
        bail!("cliphist is not installed");
    }
    match name {
        "list" => return list(p).await,
        "text" => {
            let data = decode(p.str("id")?).await?;
            let text = String::from_utf8_lossy(&data);
            // Enough for any preview; megabytes of text would only stall the UI.
            return Ok(json!(text.chars().take(200_000).collect::<String>()));
        }
        "copy" => {
            let id = p.str("id")?;
            let data = decode(id).await?;
            let mime = LINES.lock().unwrap().as_ref().and_then(|l| l.get(id).cloned()).and_then(|line| binary_meta(line.split_once('\t')?.1)).map(|(ext, _)| format!("image/{}", if ext == "jpg" { "jpeg" } else { ext.as_str() }));
            copy_bytes(&data, mime.as_deref()).await?;
            if d().settings.flag("clipboard.autoPaste") && util::which("ydotool") {
                // Ctrl+V into whatever regains focus once the popup has closed.
                tokio::spawn(async {
                    tokio::time::sleep(std::time::Duration::from_millis(250)).await;
                    let _ = util::run("ydotool", &["key", "29:1", "47:1", "47:0", "29:0"]).await;
                });
            }
        }
        "copyText" => copy_bytes(p.str("text")?.as_bytes(), None).await?,
        "delete" => {
            let id = p.str("id")?;
            let line = LINES.lock().unwrap().as_ref().and_then(|l| l.get(id).cloned()).ok_or_else(|| anyhow!("unknown clipboard entry"))?;
            util::run_with_input("cliphist", &["delete"], format!("{line}\n").as_bytes()).await?;
        }
        "wipe" => {
            util::run("cliphist", &["wipe"]).await?;
            let _ = std::fs::remove_dir_all(image_dir());
        }
        _ => bail!("unknown method clipboard.{name}"),
    }
    Ok(Value::Null)
}
