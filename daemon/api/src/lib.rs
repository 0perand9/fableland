//! `fable-plugin`: what a Fableland plugin is written against.
//!
//! A plugin is a crate named `fable-<name>` with one function:
//!
//! ```ignore
//! use fable_plugin::*;
//!
//! pub fn plugin() -> Plugin {
//!     Plugin::new()
//!         .run(|ctx| async move {
//!             // Long-running work: publish state whenever it changes.
//!             ctx.publish(json!({ "hello": "world" }));
//!             Ok(())
//!         })
//!         .call(|ctx, method, p| async move {
//!             // Answers "<name>.<method>" from the shell, the CLI and other plugins.
//!             match method.as_str() {
//!                 "greet" => Ok(json!(format!("hello, {}", p.str_or("who", "you")))),
//!                 _ => bail!("unknown method {}.{method}", ctx.name()),
//!             }
//!         })
//! }
//! ```
//!
//! It is compiled into the daemon and runs inside it, with the same reach as
//! the daemon's own modules: through [`Ctx`] it can publish topics, read and
//! write settings, call any method of any module, and do whatever Rust can.
//! docs/PLUGINS.md covers the rest: plugin.json, the shell side, installing.

use std::future::Future;
use std::path::PathBuf;
use std::pin::Pin;
use std::sync::Arc;
use std::time::Duration;

pub use ::anyhow::{self, anyhow, bail, Context as _, Result};
pub use ::chrono;
pub use ::futures_util as futures;
pub use ::serde::{self, Deserialize, Serialize};
pub use ::serde_json::{self, json, Map, Value};
pub use ::tokio;
pub use ::ureq;
pub use ::zbus;

pub use util::Params;

/// Bumped when a change to this crate can break a plugin that compiled before.
pub const API_VERSION: u32 = 1;

pub type BoxFuture<T> = Pin<Box<dyn Future<Output = T> + Send>>;

// ---------------------------------------------------------------- the plugin

type RunFn = Box<dyn Fn(Ctx) -> BoxFuture<Result<()>> + Send + Sync>;
type CallFn = Box<dyn Fn(Ctx, String, Value) -> BoxFuture<Result<Value>> + Send + Sync>;

/// What a plugin does: a task that runs for the life of the daemon, and the
/// methods it answers. Either can be left out.
#[derive(Default)]
pub struct Plugin {
    run: Option<RunFn>,
    call: Option<CallFn>,
}

impl Plugin {
    pub fn new() -> Self {
        Self::default()
    }

    /// Started once when the daemon starts (unless the plugin is switched off).
    /// An error ends the task and is logged; the rest of the daemon goes on.
    pub fn run<F, Fut>(mut self, task: F) -> Self
    where
        F: Fn(Ctx) -> Fut + Send + Sync + 'static,
        Fut: Future<Output = Result<()>> + Send + 'static,
    {
        self.run = Some(Box::new(move |ctx| Box::pin(task(ctx))));
        self
    }

    /// Answers `<name>.<method>` with the method's name and its parameters.
    pub fn call<F, Fut>(mut self, handler: F) -> Self
    where
        F: Fn(Ctx, String, Value) -> Fut + Send + Sync + 'static,
        Fut: Future<Output = Result<Value>> + Send + 'static,
    {
        self.call = Some(Box::new(move |ctx, method, params| Box::pin(handler(ctx, method, params))));
        self
    }

    #[doc(hidden)]
    pub fn start(&self, ctx: Ctx) -> Option<BoxFuture<Result<()>>> {
        self.run.as_ref().map(|run| run(ctx))
    }

    #[doc(hidden)]
    pub fn handle(&self, ctx: Ctx, method: &str, params: Value) -> Option<BoxFuture<Result<Value>>> {
        self.call.as_ref().map(|call| call(ctx, method.to_string(), params))
    }
}

/// One plugin of a build, as plugins/assemble lists them: its plugin.json and,
/// unless the plugin is QML alone, its code.
#[doc(hidden)]
pub struct Entry {
    pub manifest: &'static str,
    pub plugin: Option<Plugin>,
}

// ---------------------------------------------------------------- the daemon's side

/// What the daemon offers its plugins. Implemented by the daemon; a plugin
/// reaches it through [`Ctx`].
pub trait Host: Send + Sync + 'static {
    /// Store and broadcast the state of a topic (a no-op when nothing changed).
    fn publish(&self, topic: &str, data: Value);
    /// Broadcast a one-off event.
    fn emit(&self, event: &str, data: Value);
    /// The latest state of any topic, the daemon's own included.
    fn topic(&self, topic: &str) -> Option<Value>;
    /// Every topic and event as it goes out: lines of the protocol in docs/PROTOCOL.md.
    fn lines(&self) -> tokio::sync::broadcast::Receiver<Arc<str>>;
    /// Call any method of any module or plugin, as the shell would.
    fn call(&self, method: String, params: Value) -> BoxFuture<Result<Value>>;
    /// A setting by dotted path (Null when absent).
    fn setting(&self, path: &str) -> Value;
    fn set_setting(&self, path: &str, value: Value) -> Result<()>;
    /// Fires after every change of the settings.
    fn setting_changes(&self) -> tokio::sync::watch::Receiver<u64>;
    /// Whether a client wants an on-demand topic (docs/PROTOCOL.md).
    fn is_wanted(&self, topic: &str) -> bool;
    /// Resolves once the wanted-ness of `topic` differs from `current`.
    fn wanted_change(&self, topic: String, current: bool) -> BoxFuture<()>;
    /// A desktop notification.
    fn notify(&self, app: &str, summary: &str, body: &str, icon: &str);
    /// Start a program that outlives the daemon.
    fn spawn_detached(&self, program: &str, args: &[&str]);
    fn dirs(&self) -> Dirs;
    /// The development sandbox: the daemon observes the session but must not change it.
    fn read_only(&self) -> bool;
    fn log(&self, line: &str);
}

/// Where the daemon keeps its files.
#[derive(Clone, Debug)]
pub struct Dirs {
    /// ~/.config/fableland
    pub config: PathBuf,
    /// ~/.local/state/fableland: what must survive a reboot.
    pub state: PathBuf,
    /// ~/.cache/fableland: what can be made again.
    pub cache: PathBuf,
}

/// A plugin's handle on the daemon. Cheap to clone; pass it wherever it is needed.
#[derive(Clone)]
pub struct Ctx {
    name: &'static str,
    host: &'static dyn Host,
}

impl Ctx {
    #[doc(hidden)]
    pub fn new(name: &'static str, host: &'static dyn Host) -> Self {
        Ctx { name, host }
    }

    /// The plugin's name: its methods, topic, settings and feature go by it.
    pub fn name(&self) -> &'static str {
        self.name
    }

    /// Everything the daemon offers, for what the shortcuts below do not cover.
    pub fn host(&self) -> &'static dyn Host {
        self.host
    }

    // -- state

    /// Publish the plugin's topic, named after the plugin. The shell reads it as `Daemon.topic("<name>")`.
    pub fn publish<T: Serialize>(&self, data: T) {
        self.publish_to(self.name, data);
    }

    /// Publish any topic.
    pub fn publish_to<T: Serialize>(&self, topic: &str, data: T) {
        match serde_json::to_value(data) {
            Ok(value) => self.host.publish(topic, value),
            Err(e) => self.log(&format!("cannot serialize topic {topic}: {e}")),
        }
    }

    pub fn emit<T: Serialize>(&self, event: &str, data: T) {
        match serde_json::to_value(data) {
            Ok(value) => self.host.emit(event, value),
            Err(e) => self.log(&format!("cannot serialize event {event}: {e}")),
        }
    }

    /// A short message the shell shows as a pop-up: `kind` is "info", "success" or "error".
    pub fn toast(&self, kind: &str, title: &str, body: &str) {
        self.host.emit("toast", json!({ "kind": kind, "title": title, "body": body }));
    }

    pub fn notify(&self, summary: &str, body: &str, icon: &str) {
        self.host.notify(self.name, summary, body, icon);
    }

    /// The latest state of any topic: `ctx.topic("media")`.
    pub fn topic(&self, topic: &str) -> Option<Value> {
        self.host.topic(topic)
    }

    /// Call any method: `ctx.call("audio.setVolume", json!({ "kind": "sink", "value": 40 }))`.
    pub async fn call(&self, method: &str, params: Value) -> Result<Value> {
        self.host.call(method.to_string(), params).await
    }

    /// Whether the shell shows something that needs the plugin's topic (see `Want` in docs/SHELL.md).
    pub fn wanted(&self) -> bool {
        self.host.is_wanted(self.name)
    }

    /// Waits until the plugin's topic is wanted, or no longer wanted.
    pub async fn wanted_change(&self) {
        self.host.wanted_change(self.name.to_string(), self.wanted()).await
    }

    // -- settings

    /// One of the plugin's settings, which live under its name: `ctx.setting("url")` is `<name>.url`.
    pub fn setting(&self, key: &str) -> Value {
        self.host.setting(&format!("{}.{key}", self.name))
    }

    pub fn setting_str(&self, key: &str) -> String {
        self.setting(key).as_str().unwrap_or("").to_string()
    }

    /// All of the plugin's settings.
    pub fn settings(&self) -> Value {
        self.host.setting(self.name)
    }

    pub fn set_setting(&self, key: &str, value: Value) -> Result<()> {
        self.host.set_setting(&format!("{}.{key}", self.name), value)
    }

    /// Fires after every change of the settings (anyone's, not only the plugin's).
    pub fn setting_changes(&self) -> tokio::sync::watch::Receiver<u64> {
        self.host.setting_changes()
    }

    // -- files and programs

    /// The plugin's own directory for state that must survive a reboot.
    pub fn state_dir(&self) -> PathBuf {
        util::ensure_dir(self.host.dirs().state.join("plugins").join(self.name))
    }

    /// The plugin's own directory for what can be made again.
    pub fn cache_dir(&self) -> PathBuf {
        util::ensure_dir(self.host.dirs().cache.join("plugins").join(self.name))
    }

    /// Open a link or a file with the user's default application.
    pub fn open(&self, target: &str) {
        self.host.spawn_detached("xdg-open", &[target]);
    }

    pub fn spawn_detached(&self, program: &str, args: &[&str]) {
        self.host.spawn_detached(program, args);
    }

    /// In the development sandbox a plugin should look, not touch.
    pub fn read_only(&self) -> bool {
        self.host.read_only()
    }

    /// A line in the daemon's log, marked with the plugin's name.
    pub fn log(&self, message: &str) {
        self.host.log(&format!("{}: {message}", self.name));
    }
}

// ---------------------------------------------------------------- http

/// Blocking HTTP made async (ureq on a blocking thread), with JSON in and out.
///
/// ```ignore
/// let reply = http::get("https://example.org/api").header("X-Api-Key", key).json().await?;
/// ```
pub mod http {
    use super::*;

    pub struct Request {
        method: &'static str,
        url: String,
        headers: Vec<(String, String)>,
        body: Option<Value>,
        timeout: Duration,
    }

    pub fn get(url: impl Into<String>) -> Request {
        Request::new("GET", url.into())
    }

    pub fn post(url: impl Into<String>, body: Value) -> Request {
        Request { body: Some(body), ..Request::new("POST", url.into()) }
    }

    pub fn put(url: impl Into<String>, body: Value) -> Request {
        Request { body: Some(body), ..Request::new("PUT", url.into()) }
    }

    pub fn delete(url: impl Into<String>) -> Request {
        Request::new("DELETE", url.into())
    }

    impl Request {
        fn new(method: &'static str, url: String) -> Self {
            Request { method, url, headers: Vec::new(), body: None, timeout: Duration::from_secs(12) }
        }

        pub fn header(mut self, name: &str, value: &str) -> Self {
            self.headers.push((name.to_string(), value.to_string()));
            self
        }

        pub fn timeout(mut self, timeout: Duration) -> Self {
            self.timeout = timeout;
            self
        }

        /// Send, and read the reply as JSON (Null for an empty reply). A status
        /// of 400 or more is a [`Status`] error that carries what the server said.
        pub async fn json(self) -> Result<Value> {
            let text = self.text().await?;
            if text.trim().is_empty() {
                return Ok(Value::Null);
            }
            serde_json::from_str(&text).context("the reply is not JSON")
        }

        pub async fn text(self) -> Result<String> {
            tokio::task::spawn_blocking(move || self.send_blocking()).await?
        }

        fn send_blocking(self) -> Result<String> {
            let mut request = ureq::request(self.method, &self.url).timeout(self.timeout);
            for (name, value) in &self.headers {
                request = request.set(name, value);
            }
            let reply = match self.body {
                Some(body) => request.send_json(body),
                None => request.call(),
            };
            match reply {
                Ok(response) => Ok(response.into_string()?),
                Err(ureq::Error::Status(code, response)) => {
                    let body = response.into_string().unwrap_or_default();
                    Err(Status { code, message: explain(&body).unwrap_or_else(|| status_text(code).to_string()) }.into())
                }
                Err(ureq::Error::Transport(e)) => bail!("{}", e.message().map(str::to_string).unwrap_or_else(|| e.kind().to_string())),
            }
        }
    }

    /// The error of a reply with a status of 400 or more, for telling one
    /// status from another: `e.downcast_ref::<http::Status>()`.
    #[derive(Debug)]
    pub struct Status {
        pub code: u16,
        pub message: String,
    }

    impl std::fmt::Display for Status {
        fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
            write!(f, "{} (HTTP {})", self.message, self.code)
        }
    }

    impl std::error::Error for Status {}

    /// Whether an error is a reply with this status.
    pub fn is_status(e: &anyhow::Error, code: u16) -> bool {
        e.downcast_ref::<Status>().is_some_and(|s| s.code == code)
    }

    /// The message in an error reply, where servers usually put one.
    fn explain(body: &str) -> Option<String> {
        let value: Value = serde_json::from_str(body).ok()?;
        let first = |v: &Value| v.as_array().and_then(|a| a.first()).cloned().unwrap_or(v.clone());
        let v = first(&value);
        ["message", "errorMessage", "error", "title"].iter().find_map(|key| v.get(key).and_then(Value::as_str).map(str::to_string))
    }

    fn status_text(code: u16) -> &'static str {
        match code {
            400 => "bad request",
            401 => "not authorised (check the API key)",
            403 => "forbidden",
            404 => "not found",
            409 => "already exists",
            429 => "too many requests",
            500..=599 => "the server failed",
            _ => "request failed",
        }
    }
}

// ---------------------------------------------------------------- small helpers

/// Helpers the daemon uses itself, for plugins too.
pub mod util {
    use super::*;
    use std::path::Path;
    use std::time::{SystemTime, UNIX_EPOCH};

    pub fn home() -> PathBuf {
        PathBuf::from(std::env::var("HOME").unwrap_or_else(|_| "/".into()))
    }

    /// Expand a leading `~`.
    pub fn expand(path: &str) -> PathBuf {
        if path == "~" {
            home()
        } else if let Some(rest) = path.strip_prefix("~/") {
            home().join(rest)
        } else {
            PathBuf::from(path)
        }
    }

    pub fn ensure_dir(p: PathBuf) -> PathBuf {
        let _ = std::fs::create_dir_all(&p);
        p
    }

    /// Write a file so readers never observe a half-written state.
    pub fn write_atomic(path: &Path, bytes: &[u8]) -> Result<()> {
        if let Some(parent) = path.parent() {
            std::fs::create_dir_all(parent)?;
        }
        let tmp = path.with_extension(format!("tmp{}", std::process::id()));
        std::fs::write(&tmp, bytes)?;
        std::fs::rename(&tmp, path)?;
        Ok(())
    }

    pub fn read_json(path: &Path) -> Option<Value> {
        serde_json::from_slice(&std::fs::read(path).ok()?).ok()
    }

    pub fn write_json(path: &Path, v: &Value) -> Result<()> {
        write_atomic(path, serde_json::to_string_pretty(v)?.as_bytes())
    }

    pub fn now_ms() -> u64 {
        SystemTime::now().duration_since(UNIX_EPOCH).map(|d| d.as_millis() as u64).unwrap_or(0)
    }

    pub fn now_s() -> u64 {
        now_ms() / 1000
    }

    /// Percent-encode for a URL component.
    pub fn url_encode(s: &str) -> String {
        s.bytes().map(|b| if b.is_ascii_alphanumeric() || b"-_.~".contains(&b) { (b as char).to_string() } else { format!("%{b:02X}") }).collect()
    }

    /// Typed access to request parameters with readable error messages.
    pub trait Params {
        fn str(&self, key: &str) -> Result<&str>;
        fn str_or<'a>(&'a self, key: &str, default: &'a str) -> &'a str;
        fn num(&self, key: &str) -> Result<f64>;
        fn num_or(&self, key: &str, default: f64) -> f64;
        fn int(&self, key: &str) -> Result<i64>;
        fn flag(&self, key: &str) -> Result<bool>;
        fn flag_or(&self, key: &str, default: bool) -> bool;
    }

    impl Params for Value {
        fn str(&self, key: &str) -> Result<&str> {
            self.get(key).and_then(Value::as_str).ok_or_else(|| anyhow!("missing string parameter '{key}'"))
        }
        fn str_or<'a>(&'a self, key: &str, default: &'a str) -> &'a str {
            self.get(key).and_then(Value::as_str).unwrap_or(default)
        }
        fn num(&self, key: &str) -> Result<f64> {
            self.get(key).and_then(Value::as_f64).ok_or_else(|| anyhow!("missing number parameter '{key}'"))
        }
        fn num_or(&self, key: &str, default: f64) -> f64 {
            self.get(key).and_then(Value::as_f64).unwrap_or(default)
        }
        fn int(&self, key: &str) -> Result<i64> {
            self.num(key).map(|n| n.round() as i64)
        }
        fn flag(&self, key: &str) -> Result<bool> {
            self.get(key).and_then(Value::as_bool).ok_or_else(|| anyhow!("missing boolean parameter '{key}'"))
        }
        fn flag_or(&self, key: &str, default: bool) -> bool {
            self.get(key).and_then(Value::as_bool).unwrap_or(default)
        }
    }
}
