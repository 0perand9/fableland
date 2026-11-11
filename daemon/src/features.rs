//! Features: the parts of Fableland that can be switched off.
//!
//! `"features": { "weather": false }` in the settings leaves a part out
//! altogether: its module does not run, its methods are refused and the shell
//! shows no trace of it. What is on is decided once, when the daemon starts,
//! and published as the `features` topic — a module that never ran has nothing
//! to undo. When the setting changes, the daemon restarts itself. Every plugin
//! is a feature too, named after it.

use crate::{d, log};
use anyhow::{bail, Result};
use std::collections::BTreeMap;
use std::sync::OnceLock;

/// The daemon's own features with what they are, from features.json: the one
/// list, which the Nix module reads too.
fn core() -> &'static BTreeMap<String, String> {
    static CORE: OnceLock<BTreeMap<String, String>> = OnceLock::new();
    CORE.get_or_init(|| serde_json::from_str(include_str!("../features.json")).expect("features.json maps names to descriptions"))
}

pub fn is_core(name: &str) -> bool {
    core().contains_key(name)
}

/// Every feature: the daemon's own and one per plugin. All are on unless the settings say otherwise.
fn all() -> &'static BTreeMap<String, String> {
    static ALL: OnceLock<BTreeMap<String, String>> = OnceLock::new();
    ALL.get_or_init(|| {
        let mut all = core().clone();
        all.extend(crate::plugins::all().iter().map(|p| (p.manifest.name.clone(), p.manifest.about.clone())));
        all
    })
}

pub fn names() -> impl Iterator<Item = &'static str> {
    all().keys().map(String::as_str)
}

pub fn exists(name: &str) -> bool {
    all().contains_key(name)
}

static RUNNING: OnceLock<BTreeMap<&'static str, bool>> = OnceLock::new();

/// What the settings ask for.
fn wanted() -> BTreeMap<&'static str, bool> {
    let mut on: BTreeMap<_, _> = names().map(|name| (name, d().settings.get(&format!("features.{name}")) != false)).collect();
    // Colours are taken from the wallpaper.
    if !on["wallpaper"] {
        on.insert("palette", false);
    }
    on
}

/// Settle what is on for the life of this process, and tell the shell.
pub fn init() {
    d().hub.publish("features", RUNNING.get_or_init(wanted));
}

pub fn on(name: &str) -> bool {
    RUNNING.get().and_then(|running| running.get(name).copied()).unwrap_or(true)
}

/// An error for the user when `name` is off.
pub fn require(name: &str) -> Result<()> {
    if !on(name) {
        bail!("{name} is switched off (features.{name} in the settings)");
    }
    Ok(())
}

/// The feature a method belongs to — or, given a bare module name, the feature that module serves.
pub fn of(method: &str) -> Option<&str> {
    let (module, name) = method.split_once('.').unwrap_or((method, ""));
    match (module, name) {
        // Copying something is not the clipboard's history.
        ("clipboard", "copyText") => None,
        ("session", "lock") => Some("lock"),
        ("notif", _) => Some("notifications"),
        ("wallpaper" | "clipboard" | "capture" | "focus" | "weather" | "updates", _) => Some(module),
        _ if crate::plugins::find(module).is_some() => Some(module),
        _ => None,
    }
}

/// Start afresh when the settings ask for other features than the ones running.
pub async fn run() -> Result<()> {
    let mut changes = d().settings.changes();
    while changes.changed().await.is_ok() {
        if RUNNING.get().is_some_and(|running| *running != wanted()) {
            // The shell goes down with the daemon, and its lock screen with it: not while that is up.
            while crate::modules::power::is_locked() {
                tokio::time::sleep(std::time::Duration::from_secs(1)).await;
            }
            log!("the features in the settings changed: restarting");
            d().restart.notify_one();
        }
    }
    Ok(())
}
