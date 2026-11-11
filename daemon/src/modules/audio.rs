//! Audio devices and streams (PipeWire through its PulseAudio interface).
//!
//! `pactl subscribe` tells us when something changed; one batched `pactl list`
//! then rebuilds the `audio` topic. Nothing polls.

use crate::util::Params;
use crate::{d, log, util};
use anyhow::{bail, Result};
use serde_json::{json, Value};
use std::process::Stdio;
use std::sync::Mutex;
use std::time::Duration;
use tokio::io::{AsyncBufReadExt, BufReader};
use tokio::sync::Notify;

#[derive(Default)]
pub struct Audio {
    dirty: Notify,
    /// (name, volume, muted) of the default sink at the last refresh, for the OSD.
    last_default: Mutex<Option<(String, i64, bool)>>,
    /// Set while the shell itself is changing the volume, so no OSD pops up for it.
    quiet_until: Mutex<u64>,
}

async fn list(what: &str) -> Vec<Value> {
    match util::run("pactl", &["-f", "json", "list", what]).await {
        Ok(out) => serde_json::from_str(&out).unwrap_or_default(),
        Err(_) => Vec::new(),
    }
}

/// Loudest channel, in percent.
fn volume_of(node: &Value) -> i64 {
    node["volume"]
        .as_object()
        .map(|channels| {
            channels
                .values()
                .filter_map(|c| c["value_percent"].as_str())
                .filter_map(|p| p.trim().trim_end_matches('%').parse::<i64>().ok())
                .max()
                .unwrap_or(0)
        })
        .unwrap_or(0)
}

fn device_kind(name: &str, description: &str, props: &Value) -> &'static str {
    let form = props["device.form-factor"].as_str().unwrap_or("");
    let desc = description.to_lowercase();
    if name.contains("bluez") {
        "bluetooth"
    } else if matches!(form, "headset" | "headphone") || desc.contains("headset") || desc.contains("headphone") {
        "headset"
    } else if name.contains("hdmi") || desc.contains("hdmi") || desc.contains("displayport") {
        "display"
    } else if name.contains("usb") {
        "usb"
    } else {
        "speaker"
    }
}

fn device(node: &Value, default_name: &str) -> Value {
    let name = node["name"].as_str().unwrap_or("");
    let description = node["description"].as_str().unwrap_or(name);
    json!({
        "id": node["index"],
        "name": name,
        "description": description,
        "volume": volume_of(node),
        "muted": node["mute"].as_bool().unwrap_or(false),
        "default": name == default_name,
        "kind": device_kind(name, description, &node["properties"]),
    })
}

async fn refresh() {
    let (sinks, sources, inputs, info) = tokio::join!(list("sinks"), list("sources"), list("sink-inputs"), util::run("pactl", &["-f", "json", "info"]));
    let info: Value = info.ok().and_then(|s| serde_json::from_str(&s).ok()).unwrap_or(Value::Null);
    let default_sink = info["default_sink_name"].as_str().unwrap_or("");
    let default_source = info["default_source_name"].as_str().unwrap_or("");

    let sinks: Vec<Value> = sinks.iter().map(|s| device(s, default_sink)).collect();
    let sources: Vec<Value> = sources
        .iter()
        .filter(|s| s["properties"]["device.class"].as_str() != Some("monitor") && !s["name"].as_str().unwrap_or("").ends_with(".monitor"))
        .map(|s| device(s, default_source))
        .collect();
    let streams: Vec<Value> = inputs
        .iter()
        .filter(|i| i["properties"]["application.id"].as_str() != Some("org.PulseAudio.pavucontrol"))
        .map(|i| {
            let p = &i["properties"];
            let app = p["application.name"].as_str().or(p["application.process.binary"].as_str()).unwrap_or("Unknown app");
            let media = p["media.name"].as_str().or(p["window.title"].as_str()).or(p["media.role"].as_str()).unwrap_or("Audio stream");
            // Clients report icon names loosely; the matching desktop entry knows the real one.
            let reported = p["application.icon_name"].as_str().unwrap_or("");
            let binary = p["application.process.binary"].as_str().unwrap_or("");
            let icon = d().apps.icon_for(&[reported, binary, app]).unwrap_or_else(|| if reported.is_empty() { binary.to_string() } else { reported.to_string() });
            json!({
                "id": i["index"], "app": app, "media": media,
                "icon": icon,
                "volume": volume_of(i), "muted": i["mute"].as_bool().unwrap_or(false), "sink": i["sink"],
            })
        })
        .collect();

    let sink = sinks.iter().find(|s| s["default"] == true).cloned().unwrap_or(Value::Null);
    let source = sources.iter().find(|s| s["default"] == true).cloned().unwrap_or(Value::Null);

    // On-screen display: only for a volume/mute change on the *same* default device,
    // so plugging in headphones does not flash an OSD.
    let a = &d().audio;
    if let (Some(name), Some(volume), Some(muted)) = (sink["name"].as_str(), sink["volume"].as_i64(), sink["muted"].as_bool()) {
        let now = (name.to_string(), volume, muted);
        let mut last = a.last_default.lock().unwrap();
        if let Some(prev) = &*last {
            let quiet = util::now_ms() < *a.quiet_until.lock().unwrap();
            if prev.0 == now.0 && (prev.1 != now.1 || prev.2 != now.2) && !quiet {
                d().hub.emit("osd", &json!({ "kind": "volume", "value": volume, "muted": muted }));
            }
        }
        *last = Some(now);
    }

    d().hub.publish("audio", &json!({ "available": true, "sinks": sinks, "sources": sources, "streams": streams, "sink": sink, "source": source }));
}

pub async fn run() -> Result<()> {
    if !util::which("pactl") {
        log!("pactl not found; audio disabled");
        d().hub.publish("audio", &json!({ "available": false, "sinks": [], "sources": [], "streams": [], "sink": null, "source": null }));
        return Ok(());
    }
    tokio::spawn(async {
        let a = &d().audio;
        loop {
            a.dirty.notified().await;
            tokio::time::sleep(Duration::from_millis(20)).await;
            refresh().await;
        }
    });
    loop {
        d().audio.dirty.notify_one();
        let child = tokio::process::Command::new("pactl").arg("subscribe").stdin(Stdio::null()).stdout(Stdio::piped()).stderr(Stdio::null()).kill_on_drop(true).spawn();
        if let Ok(mut child) = child {
            if let Some(out) = child.stdout.take() {
                let mut lines = BufReader::new(out).lines();
                while let Ok(Some(line)) = lines.next_line().await {
                    // "Event 'change' on sink #57": clients come and go constantly and carry no state we show.
                    if !line.contains(" on client ") {
                        d().audio.dirty.notify_one();
                    }
                }
            }
            let _ = child.wait().await;
        }
        // The sound server went away (restart, crash): wait for it to come back.
        tokio::time::sleep(Duration::from_secs(2)).await;
    }
}

/// pactl object type and target for a (kind, id) pair.
fn target(p: &Value) -> Result<(&'static str, String)> {
    let kind = p.str_or("kind", "sink");
    let id = match p.get("id") {
        Some(Value::Number(n)) => Some(n.to_string()),
        Some(Value::String(s)) if s != "default" && !s.is_empty() => Some(s.clone()),
        _ => None,
    };
    Ok(match kind {
        "sink" => ("sink", id.unwrap_or_else(|| "@DEFAULT_SINK@".into())),
        "source" => ("source", id.unwrap_or_else(|| "@DEFAULT_SOURCE@".into())),
        "stream" => ("sink-input", id.ok_or_else(|| anyhow::anyhow!("a stream needs an id"))?),
        other => bail!("unknown audio kind '{other}'"),
    })
}

fn current(kind: &str) -> Value {
    let state = d().hub.get("audio").unwrap_or(Value::Null);
    state[if kind == "source" { "source" } else { "sink" }].clone()
}

/// Whether the device or stream a call addresses is muted, as last published.
fn is_muted(p: &Value) -> bool {
    let kind = p.str_or("kind", "sink");
    let state = d().hub.get("audio").unwrap_or(Value::Null);
    let entry = match p.get("id").and_then(Value::as_i64) {
        Some(id) => state[match kind {
            "source" => "sources",
            "stream" => "streams",
            _ => "sinks",
        }]
        .as_array()
        .and_then(|list| list.iter().find(|e| e["id"].as_i64() == Some(id)))
        .cloned()
        .unwrap_or(Value::Null),
        None => current(kind),
    };
    entry["muted"].as_bool().unwrap_or(false)
}

pub async fn call(name: &str, p: &Value) -> Result<Value> {
    let (object, id) = target(p)?;
    // Changes made from a slider should not trigger the OSD.
    if p.flag_or("quiet", false) {
        *d().audio.quiet_until.lock().unwrap() = util::now_ms() + 600;
    }
    match name {
        "setVolume" | "step" => {
            let value = if name == "step" {
                // Stepping stops at 100%; going louder is an explicit choice (setVolume).
                let cur = current(p.str_or("kind", "sink"))["volume"].as_f64().unwrap_or(0.0);
                (cur + p.num("delta")?).clamp(0.0, cur.max(100.0))
            } else {
                p.num("value")?.clamp(0.0, 150.0)
            };
            let level = format!("{}%", value.round() as i64);
            util::run("pactl", &[&format!("set-{object}-volume"), &id, &level]).await?;
            if value > 0.0 && is_muted(p) {
                // Raising the volume implies wanting to hear it. Set explicitly: a toggle could race.
                let _ = util::run("pactl", &[&format!("set-{object}-mute"), &id, "0"]).await;
            }
        }
        "setMute" => {
            let state = if p.flag("muted")? { "1" } else { "0" };
            util::run("pactl", &[&format!("set-{object}-mute"), &id, state]).await?;
        }
        "toggleMute" => {
            util::run("pactl", &[&format!("set-{object}-mute"), &id, "toggle"]).await?;
        }
        "setDefault" => {
            let kind = if p.str_or("kind", "sink") == "source" { "set-default-source" } else { "set-default-sink" };
            util::run("pactl", &[kind, p.str("name")?]).await?;
        }
        "moveStream" => {
            util::run("pactl", &["move-sink-input", &p.int("id")?.to_string(), p.str("sink")?]).await?;
        }
        _ => bail!("unknown method audio.{name}"),
    }
    d().audio.dirty.notify_one();
    Ok(Value::Null)
}
