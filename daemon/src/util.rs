//! Small shared helpers: paths, process spawning, parameter access, logging.

use anyhow::{anyhow, bail, Context, Result};
use serde_json::Value;
use std::path::{Path, PathBuf};
use std::process::Stdio;
use std::sync::OnceLock;
use std::time::{SystemTime, UNIX_EPOCH};
use tokio::process::{Child, Command};

#[macro_export]
macro_rules! log {
    ($($arg:tt)*) => { eprintln!("[fable] {}", format!($($arg)*)) };
}

// ---------------------------------------------------------------- paths

pub struct Dirs {
    /// User-edited configuration (settings.json).
    pub config: PathBuf,
    /// Data that must survive reboots (focus database, timers, usage counts).
    pub state: PathBuf,
    /// Regenerable data (thumbnails, weather, album art).
    pub cache: PathBuf,
    /// Per-session scratch space on tmpfs (socket, freeze frames).
    pub run: PathBuf,
}

pub fn home() -> PathBuf {
    PathBuf::from(std::env::var("HOME").unwrap_or_else(|_| "/".into()))
}

fn env_dir(var: &str, fallback: PathBuf) -> PathBuf {
    std::env::var(var).ok().filter(|v| !v.is_empty()).map(PathBuf::from).unwrap_or(fallback)
}

/// All directories the daemon writes to. `FABLE_HOME` relocates everything
/// under one root, which is what the dev sandbox uses to stay isolated.
pub fn dirs() -> &'static Dirs {
    static DIRS: OnceLock<Dirs> = OnceLock::new();
    DIRS.get_or_init(|| {
        let d = match std::env::var("FABLE_HOME").ok().filter(|v| !v.is_empty()) {
            Some(root) => {
                let root = PathBuf::from(root);
                Dirs { config: root.join("config"), state: root.join("state"), cache: root.join("cache"), run: root.join("run") }
            }
            None => Dirs {
                config: env_dir("XDG_CONFIG_HOME", home().join(".config")).join("fableland"),
                state: env_dir("XDG_STATE_HOME", home().join(".local/state")).join("fableland"),
                cache: env_dir("XDG_CACHE_HOME", home().join(".cache")).join("fableland"),
                run: env_dir("XDG_RUNTIME_DIR", std::env::temp_dir()).join("fableland"),
            },
        };
        for p in [&d.config, &d.state, &d.cache, &d.run] {
            let _ = std::fs::create_dir_all(p);
        }
        d
    })
}

pub fn socket_path() -> PathBuf {
    match std::env::var("FABLE_SOCK").ok().filter(|v| !v.is_empty()) {
        Some(p) => PathBuf::from(p),
        None => dirs().run.join("fable.sock"),
    }
}

/// Expand a leading `~` and return an absolute path.
pub fn expand(path: &str) -> PathBuf {
    if path == "~" {
        home()
    } else if let Some(rest) = path.strip_prefix("~/") {
        home().join(rest)
    } else {
        PathBuf::from(path)
    }
}

pub fn ensure_dir(p: &Path) -> &Path {
    let _ = std::fs::create_dir_all(p);
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

// ---------------------------------------------------------------- time

pub fn now_ms() -> u64 {
    SystemTime::now().duration_since(UNIX_EPOCH).map(|d| d.as_millis() as u64).unwrap_or(0)
}

pub fn now_s() -> u64 {
    now_ms() / 1000
}

pub fn mtime_s(path: &Path) -> u64 {
    std::fs::metadata(path)
        .and_then(|m| m.modified())
        .ok()
        .and_then(|t| t.duration_since(UNIX_EPOCH).ok())
        .map(|d| d.as_secs())
        .unwrap_or(0)
}

// ---------------------------------------------------------------- processes

/// Is `bin` on PATH?
pub fn which(bin: &str) -> bool {
    if bin.contains('/') {
        return Path::new(bin).exists();
    }
    std::env::var_os("PATH")
        .map(|paths| std::env::split_paths(&paths).any(|dir| dir.join(bin).is_file()))
        .unwrap_or(false)
}

/// First of `candidates` that is installed.
pub fn first_installed<'a>(candidates: &[&'a str]) -> Option<&'a str> {
    candidates.iter().copied().find(|c| which(c))
}

/// Run a command to completion and return its stdout. Non-zero exit is an error
/// carrying stderr, so callers can surface a real reason.
pub async fn run(cmd: &str, args: &[&str]) -> Result<String> {
    let out = Command::new(cmd)
        .args(args)
        .stdin(Stdio::null())
        .output()
        .await
        .with_context(|| format!("failed to start {cmd}"))?;
    if !out.status.success() {
        let err = String::from_utf8_lossy(&out.stderr);
        bail!("{cmd} failed: {}", err.trim().lines().last().unwrap_or("no output"));
    }
    Ok(String::from_utf8_lossy(&out.stdout).into_owned())
}

/// Like [`run`] but with bytes piped to stdin.
pub async fn run_with_input(cmd: &str, args: &[&str], input: &[u8]) -> Result<Vec<u8>> {
    use tokio::io::AsyncWriteExt;
    let mut child = Command::new(cmd)
        .args(args)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .with_context(|| format!("failed to start {cmd}"))?;
    let mut stdin = child.stdin.take().ok_or_else(|| anyhow!("no stdin"))?;
    let data = input.to_vec();
    let writer = tokio::spawn(async move {
        let _ = stdin.write_all(&data).await;
        let _ = stdin.shutdown().await;
    });
    let out = child.wait_with_output().await?;
    let _ = writer.await;
    if !out.status.success() {
        bail!("{cmd} failed: {}", String::from_utf8_lossy(&out.stderr).trim());
    }
    Ok(out.stdout)
}

/// Start a long-lived helper that we do not wait on. It is placed in its own
/// process group so a terminal Ctrl+C on the daemon does not take it down mid-write.
pub fn spawn(cmd: &str, args: &[&str]) -> Result<Child> {
    Command::new(cmd)
        .args(args)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .process_group(0)
        .spawn()
        .with_context(|| format!("failed to start {cmd}"))
}

/// Fire and forget. The program is nobody's child: it is forked once more and
/// the process in between ends at once, so it outlives the daemon and leaves
/// nothing behind for the daemon to collect.
pub fn spawn_detached(cmd: &str, args: &[&str]) {
    let mut command = Command::new(cmd);
    command.args(args).stdin(Stdio::null()).stdout(Stdio::null()).stderr(Stdio::null()).process_group(0);
    unsafe {
        command.pre_exec(|| match libc::fork() {
            -1 => Err(std::io::Error::last_os_error()),
            0 => Ok(()),
            _ => libc::_exit(0),
        });
    }
    match command.spawn() {
        Ok(mut between) => {
            tokio::spawn(async move {
                let _ = between.wait().await;
            });
        }
        Err(e) => log!("failed to start {cmd}: {e}"),
    }
}

pub fn signal(pid: u32, sig: i32) {
    unsafe {
        libc::kill(pid as i32, sig);
    }
}

/// PIDs of running processes whose executable name is exactly `name`.
pub fn pids_of(name: &str) -> Vec<u32> {
    let mut found = Vec::new();
    let Ok(entries) = std::fs::read_dir("/proc") else { return found };
    for e in entries.flatten() {
        let Some(pid) = e.file_name().to_str().and_then(|s| s.parse::<u32>().ok()) else { continue };
        if let Ok(comm) = std::fs::read_to_string(e.path().join("comm")) {
            if comm.trim() == name {
                found.push(pid);
            }
        }
    }
    found
}

/// Is any process running whose command line contains every one of `needles`?
pub fn cmdline_running(needles: &[&str]) -> bool {
    let me = std::process::id();
    let Ok(entries) = std::fs::read_dir("/proc") else { return false };
    entries.flatten().any(|e| {
        let Some(pid) = e.file_name().to_str().and_then(|s| s.parse::<u32>().ok()) else { return false };
        if pid == me {
            return false;
        }
        std::fs::read(e.path().join("cmdline"))
            .map(|raw| {
                let line = String::from_utf8_lossy(&raw).replace('\0', " ");
                needles.iter().all(|n| line.contains(n))
            })
            .unwrap_or(false)
    })
}

// ---------------------------------------------------------------- misc

/// Stable short hex digest for cache file names (not cryptographic).
pub fn hash_str(s: &str) -> String {
    let mut h: u64 = 0xcbf29ce484222325;
    for b in s.bytes() {
        h ^= b as u64;
        h = h.wrapping_mul(0x100000001b3);
    }
    format!("{h:016x}")
}

/// Quote a string as a Lua string literal for `hyprctl eval`/`dispatch`.
pub fn lua_str(s: &str) -> String {
    let mut out = String::with_capacity(s.len() + 2);
    out.push('"');
    for c in s.chars() {
        match c {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            '\0' => out.push_str("\\0"),
            c => out.push(c),
        }
    }
    out.push('"');
    out
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
