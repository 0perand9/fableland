//! fable — the Fableland daemon.
//!
//! One process owns every piece of system-side logic. The Quickshell UI is a
//! pure view: it connects to the socket in `ipc.rs`, receives state topics from
//! the hub and sends method calls back. Each file in `modules/` owns one area
//! (audio, network, wallpaper, ...) and follows the same shape:
//!
//!   pub async fn run() -> Result<()>                 long-running task, publishes topics
//!   pub async fn call(name, params) -> Result<Value> handles "<module>.<name>" requests
//!
//! Plugins (`plugins.rs`) have the same shape and are routed the same way.

mod cli;
mod dbus;
mod features;
mod hub;
mod ipc;
mod modules;
mod plugins;
mod settings;
mod util;

use anyhow::{bail, Result};
use serde_json::Value;
use std::future::Future;
use std::path::PathBuf;
use std::sync::OnceLock;

#[derive(Default)]
pub struct Daemon {
    pub hub: hub::Hub,
    pub settings: settings::Settings,
    pub hypr: modules::hypr::Hypr,
    pub ui: modules::ui::Ui,
    pub audio: modules::audio::Audio,
    pub power: modules::power::Power,
    pub net: modules::net::Net,
    pub bt: modules::bt::Bt,
    pub media: modules::media::Media,
    pub notif: modules::notif::Notif,
    pub wallpaper: modules::wallpaper::Wallpaper,
    pub apps: modules::apps::Apps,
    pub focus: modules::focus::Focus,
    pub capture: modules::capture::Capture,
    pub timers: modules::timers::Timers,
    pub weather: modules::weather::Weather,
    pub updates: modules::updates::Updates,
    /// Ends the daemon to start it afresh: `fable restart`, or a change of features.
    pub restart: tokio::sync::Notify,
}

#[derive(Default)]
pub struct Options {
    pub no_shell: bool,
    pub shell_dir: Option<PathBuf>,
    /// Development mode: observe the session but never change it.
    pub read_only: bool,
}

/// What a read-only daemon still does: queries, and state that lives only inside the daemon.
fn allowed_read_only(method: &str, p: &Value) -> bool {
    const METHODS: &[&str] = &[
        "cmd", "settings.get", "hypr.binds", "hypr.clients", "clipboard.list", "clipboard.text", "focus.stats", "focus.setIdle",
        "misc.sysinfo", "misc.xkbLayouts", "misc.suggestDirs", "misc.diaryDays", "misc.image", "misc.sound", "weather.geocode", "weather.refresh",
        "notif.dismiss", "notif.dismissApp", "notif.clear",
        "notif.test", "notif.setDnd", "wallpaper.search", "wallpaper.searchStop", "wallpaper.rescan", "apps.refresh", "updates.check", "power.refresh",
        // The lock is the shell's own, over whatever compositor it runs in.
        "session.lock", "session.unlock",
    ];
    const COSMETIC_SETTINGS: &[&str] =
        &["uiScale", "workspaceCount", "showHelpIcon", "backdrop.style", "backdrop.strength", "backdrop.speed", "backdrop.reactive"];
    METHODS.contains(&method)
        || plugins::allowed_read_only(method)
        || method.starts_with("ui.")
        || method.starts_with("timers.")
        || (method == "settings.set" && p["key"].as_str().is_some_and(|k| COSMETIC_SETTINGS.contains(&k)))
}

static DAEMON: OnceLock<Daemon> = OnceLock::new();
static OPTIONS: OnceLock<Options> = OnceLock::new();

/// The daemon singleton. Modules reach each other through this.
pub fn d() -> &'static Daemon {
    DAEMON.get().expect("daemon not initialised")
}

pub fn options() -> &'static Options {
    OPTIONS.get_or_init(Options::default)
}

/// Route "<namespace>.<name>" to the module that owns the namespace.
pub async fn dispatch(method: &str, p: &Value) -> Result<Value> {
    use modules::*;
    if options().read_only && !allowed_read_only(method, p) {
        bail!("{method} is not available: this daemon runs read-only (development sandbox)");
    }
    if let Some(feature) = features::of(method) {
        features::require(feature)?;
    }
    let (ns, name) = method.split_once('.').unwrap_or((method, ""));
    match ns {
        "cmd" => {
            let args: Vec<String> = p["args"].as_array().map(|a| a.iter().filter_map(|v| v.as_str().map(String::from)).collect()).unwrap_or_default();
            // Commands call back into dispatch, so this edge of the cycle is boxed.
            Box::pin(ui::command(&args)).await
        }
        "ui" => ui::call(name, p).await,
        "settings" => settings::call(name, p).await,
        "hypr" => hypr::call(name, p).await,
        "audio" => audio::call(name, p).await,
        "power" => power::call(name, p).await,
        "session" => power::session_call(name, p).await,
        "net" => net::call(name, p).await,
        "bt" => bt::call(name, p).await,
        "media" => media::call(name, p).await,
        "eq" => media::eq_call(name, p).await,
        "notif" => notif::call(name, p).await,
        "wallpaper" => wallpaper::call(name, p).await,
        "apps" => apps::call(name, p).await,
        "clipboard" => clipboard::call(name, p).await,
        "focus" => focus::call(name, p).await,
        "capture" => capture::call(name, p).await,
        "timers" => timers::call(name, p).await,
        "weather" => weather::call(name, p).await,
        "updates" => updates::call(name, p).await,
        "misc" => misc::call(name, p).await,
        _ => match plugins::call(ns, name, p).await {
            Some(reply) => reply,
            None => bail!("unknown method '{method}'"),
        },
    }
}

/// Run a module's task — unless the module serves a feature that is switched off.
fn start<F>(name: &'static str, task: F)
where
    F: Future<Output = Result<()>> + Send + 'static,
{
    if features::of(name).is_some_and(|feature| !features::on(feature)) {
        return;
    }
    tokio::spawn(async move {
        if let Err(e) = task.await {
            log!("module {name} stopped: {e:#}");
        }
    });
}

/// How the daemon came to its end.
enum Exit {
    Quit,
    Restart,
}

async fn daemon_main() -> Result<Exit> {
    use modules::*;
    d().settings.load();
    features::init();
    // The shell needs its colours, whatever becomes of the wallpaper module.
    wallpaper::load_palette();

    // The socket comes first so the UI can connect while modules are still warming up.
    let server = tokio::spawn(ipc::serve());
    start("settings", settings::run());
    start("features", features::run());
    start("hypr", hypr::run());
    start("audio", audio::run());
    start("power", power::run());
    start("sys", sys::run());
    start("net", net::run());
    start("bt", bt::run());
    start("media", media::run());
    start("notif", notif::run());
    start("wallpaper", wallpaper::run());
    start("apps", apps::run());
    start("clipboard", clipboard::run());
    start("focus", focus::run());
    start("capture", capture::run());
    start("timers", timers::run());
    start("weather", weather::run());
    start("updates", updates::run());
    start("misc", misc::run());
    start("ui", ui::run());
    plugins::start();

    let mut term = tokio::signal::unix::signal(tokio::signal::unix::SignalKind::terminate())?;
    let exit = tokio::select! {
        res = server => {
            res??;
            Exit::Quit
        }
        _ = tokio::signal::ctrl_c() => Exit::Quit,
        _ = term.recv() => Exit::Quit,
        _ = d().restart.notified() => Exit::Restart,
    };
    log!("shutting down");
    focus::flush();
    capture::shutdown().await;
    let _ = std::fs::remove_file(util::socket_path());
    Ok(exit)
}

/// Become a fresh daemon by running the same command line again. Where that
/// names a profile rather than a build (as on NixOS), it is the build the
/// profile holds by now: this is how an update takes effect.
fn restart() -> ! {
    use std::os::unix::process::CommandExt;
    // The helpers that went down with the runtime would haunt the new daemon as zombies.
    let patience = std::time::Instant::now() + std::time::Duration::from_secs(1);
    loop {
        match unsafe { libc::waitpid(-1, std::ptr::null_mut(), libc::WNOHANG) } {
            0 if std::time::Instant::now() < patience => std::thread::sleep(std::time::Duration::from_millis(10)),
            pid if pid > 0 => {}
            _ => break,
        }
    }
    let mut args = std::env::args_os();
    let program = args.next().unwrap_or_else(|| "fable".into());
    let error = std::process::Command::new(program).args(args).exec();
    eprintln!("fable: cannot restart: {error}");
    std::process::exit(1)
}

fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();
    if args.first().map(String::as_str) != Some("daemon") {
        std::process::exit(cli::run(args));
    }

    let mut opts = Options::default();
    let mut it = args.iter().skip(1);
    while let Some(arg) = it.next() {
        match arg.as_str() {
            "--no-shell" => opts.no_shell = true,
            "--read-only" => opts.read_only = true,
            "--shell-dir" => opts.shell_dir = it.next().map(PathBuf::from),
            other => {
                eprintln!("fable daemon: unknown option '{other}'");
                std::process::exit(2);
            }
        }
    }
    let _ = OPTIONS.set(opts);
    let _ = DAEMON.set(Daemon::default());

    let runtime = tokio::runtime::Builder::new_multi_thread().worker_threads(2).max_blocking_threads(8).enable_all().build().expect("tokio runtime");
    let exit = runtime.block_on(daemon_main());
    // Dropping the runtime kills the helper processes owned by module tasks.
    runtime.shutdown_timeout(std::time::Duration::from_millis(500));
    match exit {
        Ok(Exit::Quit) => std::process::exit(0),
        Ok(Exit::Restart) => restart(),
        Err(e) => {
            eprintln!("fable: {e:#}");
            std::process::exit(1);
        }
    }
}
