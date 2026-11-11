//! System updates for a flake-based NixOS setup (`updates` topic).
//!
//! Compares every GitHub input pinned in `flake.lock` with the newest commit on
//! the branch it follows. When something is behind, the bar shows the update
//! button; running the update opens a terminal with the configured command.

use crate::{d, log, util};
use anyhow::{anyhow, bail, Result};
use serde_json::{json, Value};
use std::path::PathBuf;
use std::sync::Mutex;
use std::time::Duration;
use tokio::sync::Notify;

#[derive(Default)]
pub struct Updates {
    check: Notify,
    state: Mutex<Value>,
}

/// The configured flake directory, or the first plausible one found.
fn flake_dir() -> Option<PathBuf> {
    let configured = d().settings.str("updates.flakeDir");
    if !configured.is_empty() {
        return Some(util::expand(&configured)).filter(|p| p.join("flake.lock").exists());
    }
    let is_system_flake = |p: &PathBuf| p.join("flake.lock").exists() && std::fs::read_to_string(p.join("flake.nix")).is_ok_and(|t| t.contains("nixosConfigurations"));
    let mut candidates = vec![PathBuf::from("/etc/nixos")];
    if let Ok(rd) = std::fs::read_dir(util::home()) {
        candidates.extend(rd.flatten().map(|e| e.path()).filter(|p| p.is_dir()));
    }
    candidates.into_iter().find(is_system_flake)
}

fn default_command() -> String {
    format!("nix flake update && sudo nixos-rebuild switch --flake .#{}", super::power::hostname())
}

fn publish(patch: Value) {
    let u = &d().updates;
    let mut state = u.state.lock().unwrap();
    if !state.is_object() {
        *state = json!({ "supported": false, "checking": false, "count": 0, "inputs": [], "lastCheck": 0 });
    }
    if let (Some(s), Some(p)) = (state.as_object_mut(), patch.as_object()) {
        for (k, v) in p {
            s.insert(k.clone(), v.clone());
        }
    }
    d().hub.publish("updates", &*state);
}

async fn check() -> Result<()> {
    publish(target());
    let Some(dir) = flake_dir() else {
        publish(json!({ "checking": false }));
        return Ok(());
    };
    publish(json!({ "checking": true }));
    let lock = util::read_json(&dir.join("flake.lock")).ok_or_else(|| anyhow!("cannot read flake.lock"))?;
    let root = lock["root"].as_str().unwrap_or("root");
    let direct = lock["nodes"][root]["inputs"].as_object().cloned().unwrap_or_default();

    let mut inputs = Vec::new();
    for (name, node_ref) in direct {
        // An input either names its node or "follows" another input (given as a path).
        let Some(node_name) = node_ref.as_str() else { continue };
        let node = &lock["nodes"][node_name];
        let (locked, original) = (&node["locked"], &node["original"]);
        let rev = locked["rev"].as_str().unwrap_or("");
        let mut entry = json!({ "name": name, "rev": rev.chars().take(7).collect::<String>(), "lockedAt": locked["lastModified"], "status": "unknown", "url": "" });
        if locked["type"] == "github" {
            let url = format!("https://github.com/{}/{}", locked["owner"].as_str().unwrap_or(""), locked["repo"].as_str().unwrap_or(""));
            entry["url"] = json!(url);
            let branch = original["ref"].as_str().unwrap_or("HEAD");
            // git's "dumb" ref listing: no API key, no rate limit worth mentioning.
            match tokio::time::timeout(Duration::from_secs(15), util::run("git", &["ls-remote", &url, branch])).await {
                Ok(Ok(out)) => {
                    let latest = out.split_whitespace().next().unwrap_or("");
                    if !latest.is_empty() {
                        entry["latest"] = json!(latest.chars().take(7).collect::<String>());
                        entry["status"] = json!(if latest == rev { "current" } else { "behind" });
                    }
                }
                _ => log!("could not query {url}"),
            }
        }
        inputs.push(entry);
    }
    inputs.sort_by(|a, b| (b["status"] == "behind").cmp(&(a["status"] == "behind")).then(a["name"].as_str().cmp(&b["name"].as_str())));
    let count = inputs.iter().filter(|i| i["status"] == "behind").count();
    publish(json!({ "checking": false, "count": count, "inputs": inputs, "lastCheck": util::now_s() }));
    Ok(())
}

/// What is being watched and how it would be updated — known before any check has run.
fn target() -> Value {
    match flake_dir() {
        Some(dir) => {
            let custom = d().settings.str("updates.command");
            json!({ "supported": true, "flakeDir": dir.to_string_lossy(), "command": if custom.is_empty() { default_command() } else { custom } })
        }
        None => json!({ "supported": false, "count": 0, "inputs": [] }),
    }
}

pub async fn run() -> Result<()> {
    publish(target());
    // Let the session settle before touching the network.
    tokio::time::sleep(Duration::from_secs(20)).await;
    loop {
        if let Err(e) = check().await {
            log!("update check: {e:#}");
            publish(json!({ "checking": false }));
        }
        let hours = d().settings.num("updates.intervalHours").max(1.0);
        tokio::select! {
            _ = tokio::time::sleep(Duration::from_secs_f64(hours * 3600.0)) => {}
            _ = d().updates.check.notified() => {}
        }
    }
}

pub async fn call(name: &str, _p: &Value) -> Result<Value> {
    match name {
        "check" => d().updates.check.notify_one(),
        "run" => {
            let dir = flake_dir().ok_or_else(|| anyhow!("no flake directory found; set one in Settings"))?;
            let custom = d().settings.str("updates.command");
            let command = if custom.is_empty() { default_command() } else { custom };
            let terminal = d().settings.str("terminal");
            // Keep the terminal open afterwards so the result can be read.
            let script = format!("cd '{}' && {command}; echo; echo '[done — press Enter to close]'; read _", dir.display());
            super::hypr::exec(&format!("{terminal} -e sh -c {}", shell_quote(&script))).await?;
            // Whatever happened, the lock file may have changed: look again shortly.
            tokio::spawn(async {
                tokio::time::sleep(Duration::from_secs(120)).await;
                d().updates.check.notify_one();
            });
        }
        _ => bail!("unknown method updates.{name}"),
    }
    Ok(Value::Null)
}

fn shell_quote(s: &str) -> String {
    format!("'{}'", s.replace('\'', "'\\''"))
}
