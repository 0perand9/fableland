//! Wi-Fi and Ethernet through NetworkManager's D-Bus API (`net` topic).
//!
//! NetworkManager signals trigger a refresh; the access point list, which is the
//! expensive part, is only walked while a client wants the `wifi` topic (the
//! network popup is open) or when the cached list has gone stale.

use crate::util::Params;
use crate::{d, dbus, log, util};
use anyhow::{anyhow, bail, Result};
use serde_json::{json, Value};
use std::collections::HashMap;
use std::sync::Mutex;
use std::time::Duration;
use tokio::sync::Notify;
use zbus::zvariant::{ObjectPath, OwnedObjectPath, OwnedValue, Value as V};
use zbus::Connection;

const NM: &str = "org.freedesktop.NetworkManager";
const NM_PATH: &str = "/org/freedesktop/NetworkManager";
const DEVICE: &str = "org.freedesktop.NetworkManager.Device";
const WIRELESS: &str = "org.freedesktop.NetworkManager.Device.Wireless";
const WIRED: &str = "org.freedesktop.NetworkManager.Device.Wired";
const ACCESS_POINT: &str = "org.freedesktop.NetworkManager.AccessPoint";
const ACTIVE: &str = "org.freedesktop.NetworkManager.Connection.Active";
const IP4: &str = "org.freedesktop.NetworkManager.IP4Config";
const SETTINGS: &str = "org.freedesktop.NetworkManager.Settings";
const SETTINGS_PATH: &str = "/org/freedesktop/NetworkManager/Settings";
const CONNECTION: &str = "org.freedesktop.NetworkManager.Settings.Connection";

#[derive(Default)]
pub struct Net {
    dirty: Notify,
    wifi_device: Mutex<String>,
    eth_device: Mutex<String>,
    /// ssid → saved connection profile path.
    saved: Mutex<HashMap<String, String>>,
    saved_stale: std::sync::atomic::AtomicBool,
    /// ssid → (access point path, security label) from the last scan walk.
    access_points: Mutex<HashMap<String, (String, String)>>,
    networks: Mutex<(u64, Vec<Value>)>,
    /// In-flight or recently failed operations, keyed by ssid or device.
    ops: Mutex<HashMap<String, String>>,
}

fn path(p: &str) -> Result<ObjectPath<'_>> {
    Ok(ObjectPath::try_from(p)?)
}

async fn paths(conn: &Connection, obj: &str, iface: &str, method: &str) -> Result<Vec<String>> {
    let reply = conn.call_method(Some(NM), obj, Some(iface), method, &()).await?;
    let list: Vec<OwnedObjectPath> = reply.body().deserialize()?;
    Ok(list.into_iter().map(|p| p.to_string()).collect())
}

fn security(ap: &Value) -> &'static str {
    let (flags, wpa, rsn) = (ap["Flags"].as_u64().unwrap_or(0), ap["WpaFlags"].as_u64().unwrap_or(0), ap["RsnFlags"].as_u64().unwrap_or(0));
    if rsn & 0x400 != 0 {
        "WPA3"
    } else if rsn & 0x200 != 0 || wpa & 0x200 != 0 {
        "Enterprise"
    } else if rsn & 0x100 != 0 {
        "WPA2"
    } else if wpa & 0x100 != 0 {
        "WPA"
    } else if flags & 0x1 != 0 {
        "WEP"
    } else {
        ""
    }
}

fn ssid_of(ap: &Value) -> String {
    let raw: Vec<u8> = ap["Ssid"].as_array().map(|a| a.iter().filter_map(|b| b.as_u64().map(|n| n as u8)).collect()).unwrap_or_default();
    String::from_utf8_lossy(&raw).into_owned()
}

async fn ip4(conn: &Connection, config_path: &str) -> String {
    if config_path.len() <= 1 {
        return String::new();
    }
    dbus::get_all(conn, NM, config_path, IP4).await.ok().and_then(|c| c["AddressData"][0]["address"].as_str().map(String::from)).unwrap_or_default()
}

async fn refresh_saved(conn: &Connection) -> Result<()> {
    let mut saved = HashMap::new();
    for p in paths(conn, SETTINGS_PATH, SETTINGS, "ListConnections").await? {
        let Ok(reply) = conn.call_method(Some(NM), p.as_str(), Some(CONNECTION), "GetSettings", &()).await else { continue };
        let Ok(settings) = reply.body().deserialize::<HashMap<String, HashMap<String, OwnedValue>>>() else { continue };
        if let Some(ssid) = settings.get("802-11-wireless").and_then(|w| w.get("ssid")).and_then(|v| dbus::bytes(v)) {
            saved.insert(String::from_utf8_lossy(&ssid).into_owned(), p);
        }
    }
    *d().net.saved.lock().unwrap() = saved;
    Ok(())
}

async fn refresh() -> Result<()> {
    let conn = dbus::system().await?;
    let n = &d().net;
    let root = dbus::get_all(&conn, NM, NM_PATH, NM).await?;
    if n.saved_stale.swap(false, std::sync::atomic::Ordering::Relaxed) {
        refresh_saved(&conn).await?;
    }

    let mut ethernet = json!({ "present": false, "connected": false });
    let mut wifi = json!({ "present": false, "enabled": false, "connected": null, "networks": [] });
    for dev_path in paths(&conn, NM_PATH, NM, "GetDevices").await? {
        let Ok(dev) = dbus::get_all(&conn, NM, &dev_path, DEVICE).await else { continue };
        let connected = dev["State"].as_u64() == Some(100);
        match dev["DeviceType"].as_u64() {
            Some(1) => {
                // With several wired ports, show the one that is actually up.
                if ethernet["present"] == true && !connected {
                    continue;
                }
                *n.eth_device.lock().unwrap() = dev_path.clone();
                let wired = dbus::get_all(&conn, NM, &dev_path, WIRED).await.unwrap_or(Value::Null);
                let name = match dev["ActiveConnection"].as_str().filter(|p| p.len() > 1) {
                    Some(active) => dbus::get_all(&conn, NM, active, ACTIVE).await.ok().and_then(|a| a["Id"].as_str().map(String::from)).unwrap_or_default(),
                    None => String::new(),
                };
                ethernet = json!({
                    "present": true, "device": dev["Interface"], "connected": connected, "name": name,
                    "ip": ip4(&conn, dev["Ip4Config"].as_str().unwrap_or("")).await,
                    "speed": wired["Speed"], "mac": dev["HwAddress"],
                    "busy": matches!(dev["State"].as_u64(), Some(40..=90)),
                });
            }
            Some(2) => {
                *n.wifi_device.lock().unwrap() = dev_path.clone();
                let w = dbus::get_all(&conn, NM, &dev_path, WIRELESS).await.unwrap_or(Value::Null);
                let mut current = Value::Null;
                let mut current_ssid = String::new();
                if let Some(ap_path) = w["ActiveAccessPoint"].as_str().filter(|p| p.len() > 1) {
                    if let Ok(ap) = dbus::get_all(&conn, NM, ap_path, ACCESS_POINT).await {
                        current_ssid = ssid_of(&ap);
                        current = json!({
                            "ssid": current_ssid, "signal": ap["Strength"], "security": security(&ap),
                            "frequency": ap["Frequency"], "ip": ip4(&conn, dev["Ip4Config"].as_str().unwrap_or("")).await,
                            "ready": connected,
                        });
                    }
                }

                let stale = util::now_s().saturating_sub(n.networks.lock().unwrap().0) > 60;
                if d().hub.is_wanted("wifi") || stale {
                    let saved = n.saved.lock().unwrap().clone();
                    let mut best: HashMap<String, Value> = HashMap::new();
                    let mut aps = HashMap::new();
                    for ap_path in paths(&conn, &dev_path, WIRELESS, "GetAllAccessPoints").await.unwrap_or_default() {
                        let Ok(ap) = dbus::get_all(&conn, NM, &ap_path, ACCESS_POINT).await else { continue };
                        let ssid = ssid_of(&ap);
                        let signal = ap["Strength"].as_u64().unwrap_or(0);
                        if ssid.is_empty() || best.get(&ssid).is_some_and(|b| b["signal"].as_u64().unwrap_or(0) >= signal) {
                            continue;
                        }
                        let sec = security(&ap);
                        aps.insert(ssid.clone(), (ap_path, sec.to_string()));
                        best.insert(ssid.clone(), json!({ "ssid": ssid, "signal": signal, "security": sec, "secure": !sec.is_empty(), "saved": saved.contains_key(&ssid), "frequency": ap["Frequency"] }));
                    }
                    let mut list: Vec<Value> = best.into_values().collect();
                    list.sort_by(|a, b| b["signal"].as_u64().cmp(&a["signal"].as_u64()).then(a["ssid"].as_str().cmp(&b["ssid"].as_str())));
                    list.truncate(40);
                    *n.access_points.lock().unwrap() = aps;
                    *n.networks.lock().unwrap() = (util::now_s(), list);
                }
                let networks: Vec<Value> = n.networks.lock().unwrap().1.iter().map(|net| {
                    let mut net = net.clone();
                    let active = net["ssid"].as_str() == Some(&current_ssid) && !current_ssid.is_empty();
                    net["active"] = json!(active);
                    if active {
                        // Show the access point in use, which need not be the strongest one of that network.
                        net["signal"] = current["signal"].clone();
                        net["frequency"] = current["frequency"].clone();
                    }
                    net
                }).collect();
                wifi = json!({
                    "present": true, "enabled": root["WirelessEnabled"].as_bool().unwrap_or(false),
                    "device": dev["Interface"], "connected": current, "networks": networks,
                });
            }
            _ => {}
        }
    }

    let primary = match root["PrimaryConnectionType"].as_str().unwrap_or("") {
        "802-3-ethernet" => "ethernet",
        "802-11-wireless" => "wifi",
        _ if ethernet["connected"] == true => "ethernet",
        _ if !wifi["connected"].is_null() => "wifi",
        _ => "none",
    };
    d().hub.publish("net", &json!({ "available": true, "ethernet": ethernet, "wifi": wifi, "primary": primary, "ops": *n.ops.lock().unwrap() }));
    Ok(())
}

pub async fn run() -> Result<()> {
    let unavailable = json!({ "available": false, "ethernet": { "present": false }, "wifi": { "present": false, "networks": [] }, "primary": "none", "ops": {} });
    let conn = match dbus::system().await {
        Ok(c) => c,
        Err(_) => {
            d().hub.publish("net", &unavailable);
            return Ok(());
        }
    };
    let n = &d().net;
    n.saved_stale.store(true, std::sync::atomic::Ordering::Relaxed);
    if let Err(e) = refresh().await {
        log!("NetworkManager unavailable: {e:#}");
        d().hub.publish("net", &unavailable);
    }
    tokio::spawn(async move {
        let _ = dbus::watch_signals(&conn, NM, None, |_, iface, _| {
            if iface == SETTINGS || iface == CONNECTION {
                d().net.saved_stale.store(true, std::sync::atomic::Ordering::Relaxed);
            }
            d().net.dirty.notify_one();
        })
        .await;
    });
    // Opening the network popup wants a fresh scan straight away.
    tokio::spawn(async {
        loop {
            d().hub.wait_wanted("wifi").await;
            let _ = call("wifiScan", &Value::Null).await;
            d().net.dirty.notify_one();
            d().hub.wait_wanted_change("wifi", true).await;
        }
    });
    loop {
        n.dirty.notified().await;
        // Signal strength updates arrive in bursts; one refresh per burst is plenty.
        let busy = !n.ops.lock().unwrap().is_empty();
        tokio::time::sleep(Duration::from_millis(if busy || d().hub.is_wanted("wifi") { 250 } else { 1000 })).await;
        if let Err(e) = refresh().await {
            log!("network refresh: {e:#}");
        }
    }
}

fn set_op(key: &str, state: Option<&str>) {
    let n = &d().net;
    match state {
        Some(s) => n.ops.lock().unwrap().insert(key.to_string(), s.to_string()),
        None => n.ops.lock().unwrap().remove(key),
    };
    n.dirty.notify_one();
}

/// Mark an operation failed for a few seconds so the UI can show it, then forget it.
fn fail_op(key: &str) {
    set_op(key, Some("failed"));
    let key = key.to_string();
    tokio::spawn(async move {
        tokio::time::sleep(Duration::from_secs(4)).await;
        if d().net.ops.lock().unwrap().get(&key).map(String::as_str) == Some("failed") {
            set_op(&key, None);
        }
    });
}

/// Wait until an activation settles. Ok(()) means connected.
async fn wait_activated(conn: &Connection, active: &str) -> Result<()> {
    for _ in 0..70 {
        tokio::time::sleep(Duration::from_millis(500)).await;
        match dbus::get_all(conn, NM, active, ACTIVE).await {
            Ok(a) => match a["State"].as_u64() {
                Some(2) => return Ok(()),
                Some(3) | Some(4) => bail!("could not connect (wrong password or network out of range)"),
                _ => {}
            },
            // The active-connection object is removed when activation fails.
            Err(_) => bail!("could not connect (wrong password or network out of range)"),
        }
    }
    bail!("connection attempt timed out")
}

async fn wifi_connect(ssid: &str, password: Option<&str>) -> Result<()> {
    let conn = dbus::system().await?;
    let n = &d().net;
    let device = n.wifi_device.lock().unwrap().clone();
    if device.is_empty() {
        bail!("no Wi-Fi adapter");
    }
    let saved = n.saved.lock().unwrap().get(ssid).cloned();
    let mut created = None;

    let active: OwnedObjectPath = match (saved, password) {
        (Some(profile), None) => {
            let reply = conn.call_method(Some(NM), NM_PATH, Some(NM), "ActivateConnection", &(path(&profile)?, path(&device)?, path("/")?)).await?;
            reply.body().deserialize()?
        }
        (saved, password) => {
            // A new password replaces whatever profile existed for this network.
            if let Some(profile) = saved {
                let _ = conn.call_method(Some(NM), profile.as_str(), Some(CONNECTION), "Delete", &()).await;
            }
            let (ap_path, sec) = n.access_points.lock().unwrap().get(ssid).cloned().ok_or_else(|| anyhow!("network '{ssid}' is no longer in range"))?;
            let mut settings: HashMap<&str, HashMap<&str, V>> = HashMap::new();
            settings.insert("connection", HashMap::from([("type", V::from("802-11-wireless")), ("id", V::from(ssid))]));
            settings.insert("802-11-wireless", HashMap::from([("ssid", V::from(ssid.as_bytes().to_vec())), ("mode", V::from("infrastructure"))]));
            if !sec.is_empty() {
                let password = password.filter(|p| !p.is_empty()).ok_or_else(|| anyhow!("this network needs a password"))?;
                let key_mgmt = if sec == "WPA3" { "sae" } else { "wpa-psk" };
                settings.insert("802-11-wireless-security", HashMap::from([("key-mgmt", V::from(key_mgmt)), ("psk", V::from(password))]));
            }
            let reply = conn.call_method(Some(NM), NM_PATH, Some(NM), "AddAndActivateConnection", &(settings, path(&device)?, path(&ap_path)?)).await?;
            let (profile, active): (OwnedObjectPath, OwnedObjectPath) = reply.body().deserialize()?;
            created = Some(profile);
            active
        }
    };

    let result = wait_activated(&conn, active.as_str()).await;
    if result.is_err() {
        // Only a profile created by this very attempt is removed; a saved network
        // that merely failed (out of range, router down) is left alone.
        if let Some(profile) = created {
            let _ = conn.call_method(Some(NM), profile.as_str(), Some(CONNECTION), "Delete", &()).await;
        }
    }
    result
}

pub async fn call(name: &str, p: &Value) -> Result<Value> {
    let conn = dbus::system().await?;
    let n = &d().net;
    let wifi = n.wifi_device.lock().unwrap().clone();
    let eth = n.eth_device.lock().unwrap().clone();
    match name {
        "wifiSetEnabled" => {
            let enabled = p.flag("enabled")?;
            dbus::set(&conn, NM, NM_PATH, NM, "WirelessEnabled", V::from(enabled)).await?;
            super::misc::play_sound(if enabled { "power_on" } else { "power_off" });
        }
        "wifiScan" => {
            if !wifi.is_empty() && !crate::options().read_only {
                // Fails harmlessly when a scan is already running.
                let _ = conn.call_method(Some(NM), wifi.as_str(), Some(WIRELESS), "RequestScan", &(HashMap::<&str, V>::new(),)).await;
            }
        }
        "wifiConnect" => {
            let ssid = p.str("ssid")?.to_string();
            set_op(&ssid, Some("connecting"));
            let result = wifi_connect(&ssid, p.get("password").and_then(Value::as_str)).await;
            match &result {
                Ok(()) => {
                    set_op(&ssid, None);
                    super::misc::play_sound("connect");
                }
                Err(_) => fail_op(&ssid),
            }
            n.saved_stale.store(true, std::sync::atomic::Ordering::Relaxed);
            result?;
        }
        "wifiDisconnect" => {
            if wifi.is_empty() {
                bail!("no Wi-Fi adapter");
            }
            conn.call_method(Some(NM), wifi.as_str(), Some(DEVICE), "Disconnect", &()).await?;
        }
        "wifiForget" => {
            let profile = n.saved.lock().unwrap().get(p.str("ssid")?).cloned().ok_or_else(|| anyhow!("that network is not saved"))?;
            conn.call_method(Some(NM), profile.as_str(), Some(CONNECTION), "Delete", &()).await?;
            n.saved_stale.store(true, std::sync::atomic::Ordering::Relaxed);
        }
        "ethernetSet" => {
            if eth.is_empty() {
                bail!("no Ethernet adapter");
            }
            if p.flag("connected")? {
                conn.call_method(Some(NM), NM_PATH, Some(NM), "ActivateConnection", &(path("/")?, path(&eth)?, path("/")?)).await?;
            } else {
                conn.call_method(Some(NM), eth.as_str(), Some(DEVICE), "Disconnect", &()).await?;
            }
        }
        _ => bail!("unknown method net.{name}"),
    }
    n.dirty.notify_one();
    Ok(Value::Null)
}
