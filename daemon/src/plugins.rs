//! Plugins: crates compiled into this build (plugins/assemble chose them), each
//! with a plugin.json that says what it is and what it adds to the shell.
//!
//! A plugin is treated like one of the daemon's own modules: it owns the
//! method namespace, topic, settings key and feature named after it, its task
//! runs alongside the modules', and it reaches the rest of the daemon through
//! the [`Host`] implemented here. docs/PLUGINS.md describes how to write one.

use crate::{d, log, options, util};
use anyhow::{anyhow, bail, Result};
use fable_plugin::{BoxFuture, Ctx, Dirs, Host, Plugin};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::collections::BTreeMap;
use std::sync::{Arc, OnceLock};

/// plugin.json.
#[derive(Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Manifest {
    pub name: String,
    #[serde(default)]
    pub title: String,
    /// A shorter title, for where the title does not fit (the rail of Settings).
    #[serde(default, skip_serializing_if = "String::is_empty")]
    pub short: String,
    /// A glyph of the icon font.
    #[serde(default)]
    pub icon: String,
    #[serde(default)]
    pub about: String,
    #[serde(default)]
    pub version: String,
    /// The defaults of the plugin's settings, which live under its name.
    #[serde(default)]
    pub settings: Value,
    /// Methods the development sandbox may call: those that change nothing outside the daemon.
    #[serde(default)]
    pub read_only: Vec<String>,
    /// What the plugin adds to the shell: files in its shell/ folder.
    #[serde(default)]
    pub shell: ShellParts,
}

#[derive(Clone, Default, Serialize, Deserialize)]
pub struct ShellParts {
    /// A popup, opened with `fable toggle <name>`.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub popup: Option<String>,
    /// Something in the bar.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub bar: Option<String>,
    /// A page in Settings.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub settings: Option<String>,
    /// Places other parts of the shell leave open, by name, and what goes there.
    #[serde(default)]
    pub slots: BTreeMap<String, String>,
}

pub struct Loaded {
    pub manifest: Manifest,
    plugin: Option<Plugin>,
}

/// Names a plugin cannot take: the daemon's own namespaces, topics, settings and popups.
const RESERVED: &[&str] = &[
    "cmd", "ui", "settings", "managed", "features", "plugins", "hypr", "monitors", "audio", "power", "session", "net", "bt", "media", "eq",
    "theme", "notif", "wallpaper", "wallsearch", "apps", "clipboard", "focus", "capture", "timers", "weather", "updates", "schedule",
    "sys", "sysinfo", "misc", "launcher", "calendar", "music", "network", "volume", "control", "guide", "assistant", "quick",
    "lock", "idle", "keyboard", "keybinds", "startup", "diary", "osd", "sounds", "backdrop", "terminal",
];

fn check(manifest: &Manifest, taken: &[Loaded]) -> Result<()> {
    let name = manifest.name.as_str();
    let valid = name.chars().next().is_some_and(|c| c.is_ascii_lowercase()) && name.chars().all(|c| c.is_ascii_lowercase() || c.is_ascii_digit());
    if !valid {
        bail!("its name must be lowercase letters and digits, starting with a letter");
    }
    if RESERVED.contains(&name) || crate::settings::core_defaults().get(name).is_some() || crate::features::is_core(name) {
        bail!("'{name}' is a name of the daemon's own");
    }
    if taken.iter().any(|p| p.manifest.name == name) {
        bail!("another plugin is already called '{name}'");
    }
    if !manifest.settings.is_null() && !manifest.settings.is_object() {
        bail!("its settings must be an object of defaults");
    }
    Ok(())
}

/// The plugins of this build, in the order plugins/assemble listed them. One
/// whose plugin.json is unusable is left out, with a line in the log.
pub fn all() -> &'static [Loaded] {
    static ALL: OnceLock<Vec<Loaded>> = OnceLock::new();
    ALL.get_or_init(|| {
        let mut loaded: Vec<Loaded> = Vec::new();
        for entry in fable_plugin_set::all() {
            let manifest = serde_json::from_str::<Manifest>(entry.manifest).map_err(|e| anyhow!("its plugin.json is invalid: {e}"));
            match manifest.and_then(|m| check(&m, &loaded).map(|_| m)) {
                Ok(manifest) => loaded.push(Loaded { manifest, plugin: entry.plugin }),
                Err(e) => {
                    let name = serde_json::from_str::<Value>(entry.manifest).ok().and_then(|v| v["name"].as_str().map(str::to_string));
                    log!("leaving out the plugin {}: {e:#}", name.as_deref().unwrap_or("(unnamed)"));
                }
            }
        }
        loaded
    })
}

pub fn find(name: &str) -> Option<&'static Loaded> {
    all().iter().find(|p| p.manifest.name == name)
}

/// The defaults of every plugin's settings, by plugin name.
pub fn default_settings() -> impl Iterator<Item = (&'static str, &'static Value)> {
    all().iter().filter(|p| p.manifest.settings.is_object()).map(|p| (p.manifest.name.as_str(), &p.manifest.settings))
}

/// Whether the development sandbox may call `method` of a plugin.
pub fn allowed_read_only(method: &str) -> bool {
    let (ns, name) = method.split_once('.').unwrap_or((method, ""));
    find(ns).is_some_and(|p| p.manifest.read_only.iter().any(|m| m == name))
}

fn ctx(plugin: &'static Loaded) -> Ctx {
    Ctx::new(&plugin.manifest.name, &HOST)
}

/// Tell the shell what the plugins add to it, and start their tasks.
pub fn start() {
    let manifests: Vec<&Manifest> = all().iter().map(|p| &p.manifest).collect();
    d().hub.publish("plugins", &manifests);
    for plugin in all() {
        if let Some(task) = plugin.plugin.as_ref().and_then(|code| code.start(ctx(plugin))) {
            crate::start(&plugin.manifest.name, task);
        }
    }
}

/// Route `<plugin>.<method>`; None when no plugin goes by that namespace.
pub async fn call(namespace: &str, method: &str, p: &Value) -> Option<Result<Value>> {
    let plugin = find(namespace)?;
    let Some(reply) = plugin.plugin.as_ref().and_then(|code| code.handle(ctx(plugin), method, p.clone())) else {
        return Some(Err(anyhow!("the plugin {namespace} answers no methods")));
    };
    Some(reply.await)
}

// ---------------------------------------------------------------- the host

struct DaemonHost;

static HOST: DaemonHost = DaemonHost;

impl Host for DaemonHost {
    fn publish(&self, topic: &str, data: Value) {
        d().hub.publish(topic, &data);
    }

    fn emit(&self, event: &str, data: Value) {
        d().hub.emit(event, &data);
    }

    fn topic(&self, topic: &str) -> Option<Value> {
        d().hub.get(topic)
    }

    fn lines(&self) -> tokio::sync::broadcast::Receiver<Arc<str>> {
        d().hub.subscribe()
    }

    fn call(&self, method: String, params: Value) -> BoxFuture<Result<Value>> {
        Box::pin(async move { crate::dispatch(&method, &params).await })
    }

    fn setting(&self, path: &str) -> Value {
        d().settings.get(path)
    }

    fn set_setting(&self, path: &str, value: Value) -> Result<()> {
        d().settings.set(path, value)
    }

    fn setting_changes(&self) -> tokio::sync::watch::Receiver<u64> {
        d().settings.changes()
    }

    fn is_wanted(&self, topic: &str) -> bool {
        d().hub.is_wanted(topic)
    }

    fn wanted_change(&self, topic: String, current: bool) -> BoxFuture<()> {
        Box::pin(async move { d().hub.wait_wanted_change(&topic, current).await })
    }

    fn notify(&self, app: &str, summary: &str, body: &str, icon: &str) {
        crate::modules::notif::notify(crate::modules::notif::Note { app, summary, body, icon, image: "", actions: Vec::new() });
    }

    fn spawn_detached(&self, program: &str, args: &[&str]) {
        util::spawn_detached(program, args);
    }

    fn dirs(&self) -> Dirs {
        let dirs = util::dirs();
        Dirs { config: dirs.config.clone(), state: dirs.state.clone(), cache: dirs.cache.clone() }
    }

    fn read_only(&self) -> bool {
        options().read_only
    }

    fn log(&self, line: &str) {
        log!("{line}");
    }
}
