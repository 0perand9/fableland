//! Bluetooth through BlueZ (`bt` topic). One `GetManagedObjects` call yields the
//! adapter and every device, and BlueZ signals tell us when to ask again.
//! Discovery only runs while a client wants the `btscan` topic.

use crate::util::Params;
use crate::{d, dbus, log};
use anyhow::{anyhow, bail, Result};
use serde_json::{json, Value};
use std::collections::HashMap;
use std::sync::Mutex;
use std::time::Duration;
use tokio::sync::Notify;
use zbus::zvariant::{ObjectPath, OwnedObjectPath, Value as V};

const BLUEZ: &str = "org.bluez";
const ADAPTER: &str = "org.bluez.Adapter1";
const DEVICE: &str = "org.bluez.Device1";

#[derive(Default)]
pub struct Bt {
    dirty: Notify,
    adapter: Mutex<String>,
    /// mac → device object path.
    devices: Mutex<HashMap<String, String>>,
    ops: Mutex<HashMap<String, String>>,
    powered: std::sync::atomic::AtomicBool,
}

fn kind(icon: &str, name: &str) -> &'static str {
    let n = name.to_lowercase();
    let has = |words: &[&str]| words.iter().any(|w| n.contains(w));
    match icon {
        "audio-headset" | "audio-headphones" => "headset",
        "audio-card" | "audio-speakers" => "speaker",
        "phone" => "phone",
        "input-mouse" => "mouse",
        "input-keyboard" => "keyboard",
        "input-gaming" => "gamepad",
        "computer" => "computer",
        _ if has(&["buds", "pods", "headphone", "headset"]) => "headset",
        _ if has(&["speaker", "soundbar"]) => "speaker",
        _ if has(&["mouse"]) => "mouse",
        _ if has(&["keyboard"]) => "keyboard",
        _ if has(&["controller", "gamepad"]) => "gamepad",
        _ if has(&["phone", "pixel", "galaxy"]) => "phone",
        _ => "generic",
    }
}

async fn refresh() -> Result<()> {
    let conn = dbus::system().await?;
    let reply = conn.call_method(Some(BLUEZ), "/", Some("org.freedesktop.DBus.ObjectManager"), "GetManagedObjects", &()).await?;
    let objects: HashMap<OwnedObjectPath, HashMap<String, dbus::Props>> = reply.body().deserialize()?;
    let b = &d().bt;

    let mut adapter = None;
    let (mut connected, mut others, mut paths) = (Vec::new(), Vec::new(), HashMap::new());
    for (path, ifaces) in &objects {
        if let Some(a) = ifaces.get(ADAPTER) {
            // The first adapter is the one we drive.
            if adapter.is_none() {
                adapter = Some((path.to_string(), dbus::props_to_json(a)));
            }
        }
        let Some(dev) = ifaces.get(DEVICE).map(dbus::props_to_json) else { continue };
        let mac = dev["Address"].as_str().unwrap_or("").to_string();
        let name = dev["Alias"].as_str().or(dev["Name"].as_str()).unwrap_or("").to_string();
        let paired = dev["Paired"].as_bool().unwrap_or(false);
        // Unnamed, unpaired devices are advertising beacons nobody wants to see.
        let anonymous = name.is_empty() || name.replace('-', ":").eq_ignore_ascii_case(&mac);
        if anonymous && !paired {
            continue;
        }
        paths.insert(mac.clone(), path.to_string());
        let battery = ifaces.get("org.bluez.Battery1").map(dbus::props_to_json).map(|p| p["Percentage"].clone()).unwrap_or(Value::Null);
        let entry = json!({
            "mac": mac, "name": name, "kind": kind(dev["Icon"].as_str().unwrap_or(""), &name),
            "paired": paired, "trusted": dev["Trusted"], "rssi": dev["RSSI"], "battery": battery,
        });
        if dev["Connected"].as_bool().unwrap_or(false) {
            connected.push(entry);
        } else {
            others.push(entry);
        }
    }
    let by_name = |a: &Value, b: &Value| a["name"].as_str().cmp(&b["name"].as_str());
    connected.sort_by(by_name);
    others.sort_by(|a, b| b["paired"].as_bool().cmp(&a["paired"].as_bool()).then(b["rssi"].as_i64().unwrap_or(-200).cmp(&a["rssi"].as_i64().unwrap_or(-200))).then(by_name(a, b)));
    others.truncate(40);

    *b.devices.lock().unwrap() = paths;
    let (adapter_path, props) = adapter.unwrap_or_default();
    let present = !adapter_path.is_empty();
    *b.adapter.lock().unwrap() = adapter_path;
    let powered = props["Powered"].as_bool().unwrap_or(false);
    b.powered.store(powered, std::sync::atomic::Ordering::Relaxed);
    d().hub.publish(
        "bt",
        &json!({
            "present": present, "powered": powered, "discovering": props["Discovering"].as_bool().unwrap_or(false),
            "connected": connected, "devices": others, "ops": *b.ops.lock().unwrap(),
        }),
    );
    Ok(())
}

pub async fn run() -> Result<()> {
    let absent = json!({ "present": false, "powered": false, "discovering": false, "connected": [], "devices": [], "ops": {} });
    let Ok(conn) = dbus::system().await else {
        d().hub.publish("bt", &absent);
        return Ok(());
    };
    if refresh().await.is_err() {
        // BlueZ is not running (or not installed); it may still appear later.
        d().hub.publish("bt", &absent);
    }
    tokio::spawn(async move {
        let _ = dbus::watch_signals(&conn, BLUEZ, None, |_, _, _| d().bt.dirty.notify_one()).await;
    });
    // Scan for new devices only while the Bluetooth view is open.
    tokio::spawn(async {
        loop {
            d().hub.wait_wanted("btscan").await;
            let _ = discovery(true).await;
            d().hub.wait_wanted_change("btscan", true).await;
            let _ = discovery(false).await;
        }
    });
    loop {
        d().bt.dirty.notified().await;
        tokio::time::sleep(Duration::from_millis(250)).await;
        if let Err(e) = refresh().await {
            log!("bluetooth refresh: {e:#}");
            d().hub.publish("bt", &absent);
        }
    }
}

async fn discovery(on: bool) -> Result<()> {
    let adapter = d().bt.adapter.lock().unwrap().clone();
    if adapter.is_empty() || !d().bt.powered.load(std::sync::atomic::Ordering::Relaxed) || crate::options().read_only {
        return Ok(());
    }
    let conn = dbus::system().await?;
    conn.call_method(Some(BLUEZ), adapter.as_str(), Some(ADAPTER), if on { "StartDiscovery" } else { "StopDiscovery" }, &()).await?;
    Ok(())
}

fn set_op(mac: &str, state: Option<&str>) {
    let b = &d().bt;
    match state {
        Some(s) => b.ops.lock().unwrap().insert(mac.to_string(), s.to_string()),
        None => b.ops.lock().unwrap().remove(mac),
    };
    b.dirty.notify_one();
}

async fn device_call(path: &str, method: &str) -> Result<()> {
    let conn = dbus::system().await?;
    // BlueZ answers a failed connect only after its own long timeout; cap the wait.
    tokio::time::timeout(Duration::from_secs(35), conn.call_method(Some(BLUEZ), path, Some(DEVICE), method, &()))
        .await
        .map_err(|_| anyhow!("the device did not respond"))??;
    Ok(())
}

async fn connect(path: &str) -> Result<()> {
    let conn = dbus::system().await?;
    let props = dbus::get_all(&conn, BLUEZ, path, DEVICE).await?;
    // Trusting lets the device reconnect on its own later.
    dbus::set(&conn, BLUEZ, path, DEVICE, "Trusted", V::from(true)).await?;
    if !props["Paired"].as_bool().unwrap_or(false) {
        device_call(path, "Pair").await?;
    }
    device_call(path, "Connect").await
}

pub async fn call(name: &str, p: &Value) -> Result<Value> {
    let b = &d().bt;
    let conn = dbus::system().await?;
    let adapter = b.adapter.lock().unwrap().clone();
    let device = |p: &Value| -> Result<(String, String)> {
        let mac = p.str("mac")?.to_string();
        let path = b.devices.lock().unwrap().get(&mac).cloned().ok_or_else(|| anyhow!("unknown device {mac}"))?;
        Ok((mac, path))
    };
    match name {
        "setPowered" => {
            if adapter.is_empty() {
                bail!("no Bluetooth adapter");
            }
            let on = p.flag("on")?;
            dbus::set(&conn, BLUEZ, &adapter, ADAPTER, "Powered", V::from(on)).await?;
            super::misc::play_sound(if on { "power_on" } else { "power_off" });
            if on && d().hub.is_wanted("btscan") {
                tokio::spawn(async {
                    tokio::time::sleep(Duration::from_millis(800)).await;
                    d().bt.powered.store(true, std::sync::atomic::Ordering::Relaxed);
                    let _ = discovery(true).await;
                });
            }
        }
        "connect" | "disconnect" => {
            let (mac, path) = device(p)?;
            set_op(&mac, Some(if name == "connect" { "connecting" } else { "disconnecting" }));
            let result = if name == "connect" { connect(&path).await } else { device_call(&path, "Disconnect").await };
            match &result {
                Ok(()) => {
                    set_op(&mac, None);
                    super::misc::play_sound(name);
                }
                Err(_) => {
                    set_op(&mac, Some("failed"));
                    tokio::spawn(async move {
                        tokio::time::sleep(Duration::from_secs(4)).await;
                        set_op(&mac, None);
                    });
                }
            }
            result?;
        }
        "remove" => {
            let (_, path) = device(p)?;
            conn.call_method(Some(BLUEZ), adapter.as_str(), Some(ADAPTER), "RemoveDevice", &(ObjectPath::try_from(path.as_str())?,)).await?;
        }
        _ => bail!("unknown method bt.{name}"),
    }
    b.dirty.notify_one();
    Ok(Value::Null)
}
