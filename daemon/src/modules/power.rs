//! Power and session: battery (UPower), power profiles, backlight, and
//! lock / suspend / reboot / poweroff / logout. Publishes `power` and `session`.

use crate::util::Params;
use crate::{d, dbus, features, log, util};
use anyhow::{anyhow, bail, Result};
use serde_json::{json, Value};
use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Mutex;
use std::time::Duration;
use tokio::sync::Notify;
use zbus::zvariant::Value as V;

const UPOWER: &str = "org.freedesktop.UPower";
const UPOWER_DEVICE: &str = "org.freedesktop.UPower.Device";
const LOGIN: &str = "org.freedesktop.login1";
/// power-profiles-daemon answers under one of these names depending on its version.
const PROFILE_SERVICES: [(&str, &str); 2] = [("org.freedesktop.UPower.PowerProfiles", "/org/freedesktop/UPower/PowerProfiles"), ("net.hadess.PowerProfiles", "/net/hadess/PowerProfiles")];

#[derive(Default)]
pub struct Power {
    dirty: Notify,
    locked: AtomicBool,
    profile_service: Mutex<Option<(&'static str, &'static str)>>,
}

fn backlight() -> Option<PathBuf> {
    std::fs::read_dir("/sys/class/backlight").ok()?.flatten().map(|e| e.path()).next()
}

fn read_num(path: PathBuf) -> Option<f64> {
    std::fs::read_to_string(path).ok()?.trim().parse().ok()
}

fn brightness() -> Value {
    let Some(dev) = backlight() else { return json!({ "present": false, "percent": 100 }) };
    let max = read_num(dev.join("max_brightness")).unwrap_or(1.0).max(1.0);
    let cur = read_num(dev.join("brightness")).unwrap_or(max);
    json!({ "present": true, "percent": (cur / max * 100.0).round() })
}

fn battery_state(code: u64) -> &'static str {
    match code {
        1 => "charging",
        2 => "discharging",
        3 => "empty",
        4 => "full",
        5 => "pending-charge",
        6 => "pending-discharge",
        _ => "unknown",
    }
}

fn peripheral_kind(kind: u64) -> Option<&'static str> {
    Some(match kind {
        5 => "mouse",
        6 => "keyboard",
        8 => "phone",
        12 => "gamepad",
        13 => "pen",
        14 => "touchpad",
        17 | 19 => "headset",
        18 => "speaker",
        4 | 7 | 9 | 10 | 11 => "device",
        _ => return None,
    })
}

async fn refresh() -> Result<()> {
    let conn = dbus::system().await?;
    let mut battery = json!({ "present": false, "percent": 100, "state": "unknown", "charging": false });
    let mut peripherals = Vec::new();

    if let Ok(dev) = dbus::get_all(&conn, UPOWER, "/org/freedesktop/UPower/devices/DisplayDevice", UPOWER_DEVICE).await {
        let state = dev["State"].as_u64().unwrap_or(0);
        if dev["IsPresent"].as_bool().unwrap_or(false) {
            battery = json!({
                "present": true,
                "percent": dev["Percentage"].as_f64().unwrap_or(0.0).round(),
                "state": battery_state(state),
                // Plugged in and topped up still counts as "on power".
                "charging": matches!(state, 1 | 4 | 5),
                "timeToEmpty": dev["TimeToEmpty"], "timeToFull": dev["TimeToFull"],
            });
        }
    }
    if let Ok(reply) = conn.call_method(Some(UPOWER), "/org/freedesktop/UPower", Some(UPOWER), "EnumerateDevices", &()).await {
        let paths: Vec<zbus::zvariant::OwnedObjectPath> = reply.body().deserialize().unwrap_or_default();
        for path in paths {
            let Ok(dev) = dbus::get_all(&conn, UPOWER, path.as_str(), UPOWER_DEVICE).await else { continue };
            let Some(kind) = peripheral_kind(dev["Type"].as_u64().unwrap_or(0)) else { continue };
            peripherals.push(json!({
                "id": path.as_str().rsplit('/').next().unwrap_or(""),
                "name": dev["Model"].as_str().filter(|m| !m.is_empty()).unwrap_or(kind),
                "kind": kind,
                "percent": dev["Percentage"].as_f64().unwrap_or(0.0).round(),
                "charging": dev["State"].as_u64() == Some(1),
            }));
        }
    }

    let (mut profile, mut profiles) = (Value::Null, Vec::new());
    let service = *d().power.profile_service.lock().unwrap();
    if let Some((dest, path)) = service {
        if let Ok(p) = dbus::get_all(&conn, dest, path, dest).await {
            profile = p["ActiveProfile"].clone();
            profiles = p["Profiles"].as_array().map(|a| a.iter().filter_map(|e| e["Profile"].as_str().map(String::from)).collect()).unwrap_or_default();
        }
    }

    d().hub.publish(
        "power",
        &json!({
            "battery": battery, "peripherals": peripherals, "profile": profile, "profiles": profiles,
            "brightness": brightness(),
            "bootTime": boot_time(), "user": std::env::var("USER").unwrap_or_default(), "host": hostname(),
        }),
    );
    Ok(())
}

fn boot_time() -> u64 {
    static BOOT: std::sync::OnceLock<u64> = std::sync::OnceLock::new();
    *BOOT.get_or_init(|| {
        let up = std::fs::read_to_string("/proc/uptime").ok().and_then(|s| s.split_whitespace().next().and_then(|v| v.parse::<f64>().ok())).unwrap_or(0.0);
        util::now_s().saturating_sub(up as u64)
    })
}

pub fn hostname() -> String {
    std::fs::read_to_string("/proc/sys/kernel/hostname").map(|s| s.trim().to_string()).unwrap_or_default()
}

fn publish_session() {
    d().hub.publish("session", &json!({ "locked": d().power.locked.load(Ordering::Relaxed) }));
}

pub fn is_locked() -> bool {
    d().power.locked.load(Ordering::Relaxed)
}

/// Exists while the session is locked. It lives in the runtime directory, so
/// it outlasts a restart of the daemon but not the login session.
fn lock_marker() -> std::path::PathBuf {
    util::dirs().run.join("locked")
}

fn set_locked(locked: bool) {
    // Without the lock screen, locking is another program's business.
    if locked && !features::on("lock") {
        return;
    }
    d().power.locked.store(locked, Ordering::Relaxed);
    if locked {
        let _ = std::fs::write(lock_marker(), b"");
    } else {
        let _ = std::fs::remove_file(lock_marker());
    }
    publish_session();
}

pub async fn run() -> Result<()> {
    // A daemon restarted under a locked session must not report it as open.
    d().power.locked.store(features::on("lock") && lock_marker().exists(), Ordering::Relaxed);
    publish_session();
    let conn = match dbus::system().await {
        Ok(c) => c,
        Err(e) => {
            log!("system bus unavailable ({e:#}); power information disabled");
            d().hub.publish("power", &json!({ "battery": { "present": false }, "peripherals": [], "profiles": [], "brightness": brightness(), "bootTime": boot_time(), "user": std::env::var("USER").unwrap_or_default(), "host": hostname() }));
            return Ok(());
        }
    };
    for (dest, path) in PROFILE_SERVICES {
        if dbus::get_all(&conn, dest, path, dest).await.is_ok() {
            *d().power.profile_service.lock().unwrap() = Some((dest, path));
            let c = conn.clone();
            tokio::spawn(async move {
                let _ = dbus::watch_signals(&c, dest, None, |_, _, _| d().power.dirty.notify_one()).await;
            });
            break;
        }
    }

    let c = conn.clone();
    tokio::spawn(async move {
        let _ = dbus::watch_signals(&c, UPOWER, None, |_, _, _| d().power.dirty.notify_one()).await;
    });
    // `loginctl lock-session`, and locking before the machine goes to sleep.
    // A read-only daemon is not what locks this session, and stays out of it.
    if !crate::options().read_only {
        let c = conn.clone();
        tokio::spawn(async move {
            let _ = dbus::watch_signals(&c, LOGIN, None, |_, iface, member| match (iface, member) {
                ("org.freedesktop.login1.Session", "Lock") | ("org.freedesktop.login1.Manager", "PrepareForSleep") => set_locked(true),
                _ => {}
            })
            .await;
        });
    }
    // The backlight has no change signal; when one exists, look at it now and then.
    if backlight().is_some() {
        tokio::spawn(async {
            loop {
                tokio::time::sleep(Duration::from_secs(3)).await;
                d().power.dirty.notify_one();
            }
        });
    }

    loop {
        if let Err(e) = refresh().await {
            log!("power refresh: {e:#}");
        }
        d().power.dirty.notified().await;
        tokio::time::sleep(Duration::from_millis(150)).await;
    }
}

async fn set_brightness(p: &Value) -> Result<()> {
    let dev = backlight().ok_or_else(|| anyhow!("this machine has no adjustable backlight"))?;
    let max = read_num(dev.join("max_brightness")).unwrap_or(100.0).max(1.0);
    let cur = read_num(dev.join("brightness")).unwrap_or(max) / max * 100.0;
    let wanted = if p.flag_or("relative", false) { cur + p.num("value")? } else { p.num("value")? };
    // Never go fully dark: a black screen is hard to recover from.
    let percent = wanted.clamp(1.0, 100.0);
    let raw = (percent / 100.0 * max).round().max(1.0) as u32;
    let name = dev.file_name().and_then(|n| n.to_str()).unwrap_or_default();
    let conn = dbus::system().await?;
    conn.call_method(Some(LOGIN), "/org/freedesktop/login1/session/auto", Some("org.freedesktop.login1.Session"), "SetBrightness", &("backlight", name, raw)).await?;
    if !p.flag_or("quiet", false) {
        d().hub.emit("osd", &json!({ "kind": "brightness", "value": percent.round() }));
    }
    d().power.dirty.notify_one();
    Ok(())
}

async fn systemctl(action: &str) -> Result<()> {
    util::run("systemctl", &[action]).await.map(|_| ())
}

/// Calls in the `power.*` namespace.
pub async fn call(name: &str, p: &Value) -> Result<Value> {
    match name {
        "setBrightness" => set_brightness(p).await?,
        "setProfile" => {
            let (dest, path) = d().power.profile_service.lock().unwrap().ok_or_else(|| anyhow!("power-profiles-daemon is not running"))?;
            let conn = dbus::system().await?;
            dbus::set(&conn, dest, path, dest, "ActiveProfile", V::from(p.str("profile")?)).await?;
            d().power.dirty.notify_one();
        }
        "refresh" => d().power.dirty.notify_one(),
        _ => bail!("unknown method power.{name}"),
    }
    Ok(Value::Null)
}

/// Calls in the `session.*` namespace.
pub async fn session_call(name: &str, p: &Value) -> Result<Value> {
    match name {
        "lock" => set_locked(true),
        // Sent by the lock screen after PAM accepted the password.
        "unlock" => set_locked(false),
        "suspend" => {
            set_locked(true);
            // Give the lock surface a moment to cover the screen before the lid goes dark.
            tokio::time::sleep(Duration::from_millis(400)).await;
            systemctl("suspend").await?;
        }
        "reboot" => systemctl("reboot").await?,
        "poweroff" => systemctl("poweroff").await?,
        "logout" => {
            let _ = util::run("systemctl", &["--user", "stop", "graphical-session.target"]).await;
            super::hypr::dispatch("hl.dsp.exit()").await?;
        }
        "screen" => {
            let action = if p.flag("on")? { "on" } else { "off" };
            super::hypr::dispatch(&format!("hl.dsp.dpms({{ action = \"{action}\" }})")).await?;
        }
        _ => bail!("unknown method session.{name}"),
    }
    Ok(Value::Null)
}
