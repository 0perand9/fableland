//! Media players over MPRIS (`media` topic) and the equalizer (`eq` topic).
//!
//! Player signals drive refreshes. Position is published together with the time
//! it was read, so the UI can advance the progress bar on its own.

use crate::util::Params;
use crate::{d, dbus, log, util};
use anyhow::{anyhow, bail, Result};
use serde_json::{json, Value};
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::sync::Mutex;
use std::time::Duration;
use tokio::sync::Notify;
use zbus::zvariant::ObjectPath;

const PREFIX: &str = "org.mpris.MediaPlayer2.";
const PATH: &str = "/org/mpris/MediaPlayer2";
const PLAYER: &str = "org.mpris.MediaPlayer2.Player";
const ROOT: &str = "org.mpris.MediaPlayer2";

#[derive(Default)]
pub struct Media {
    dirty: Notify,
    /// bus name → ("status|title", time that pair last changed). Decides which player is "current".
    memo: Mutex<HashMap<String, (String, u64)>>,
    selected: Mutex<String>,
    active: Mutex<Value>,
    /// art url → local file + colours, or None while it is being fetched.
    art: Mutex<HashMap<String, Option<Art>>>,
    eq: Mutex<Option<Eq>>,
}

#[derive(Clone)]
struct Art {
    path: String,
    palette: Vec<String>,
}

// ---------------------------------------------------------------- album art

fn url_decode(s: &str) -> String {
    let bytes = s.as_bytes();
    let mut out = Vec::with_capacity(bytes.len());
    let mut i = 0;
    while i < bytes.len() {
        if bytes[i] == b'%' && i + 2 < bytes.len() {
            let digit = |b: u8| (b as char).to_digit(16);
            if let (Some(hi), Some(lo)) = (digit(bytes[i + 1]), digit(bytes[i + 2])) {
                out.push((hi * 16 + lo) as u8);
                i += 3;
                continue;
            }
        }
        out.push(bytes[i]);
        i += 1;
    }
    String::from_utf8_lossy(&out).into_owned()
}

fn hex(c: [f64; 3]) -> String {
    format!("#{:02x}{:02x}{:02x}", c[0].round() as u8, c[1].round() as u8, c[2].round() as u8)
}

/// Three dominant, mutually distinct colours of an image, most prominent first.
/// Saturated colours are weighted up so a mostly grey cover still yields its accent.
pub fn palette(path: &Path) -> Option<Vec<String>> {
    let img = image::open(path).ok()?.thumbnail(64, 64).to_rgb8();
    let mut bins: HashMap<u16, (f64, [f64; 3])> = HashMap::new();
    for px in img.pixels() {
        let [r, g, b] = px.0;
        let (max, min) = (r.max(g).max(b) as f64, r.min(g).min(b) as f64);
        let saturation = if max > 0.0 { (max - min) / max } else { 0.0 };
        let weight = 1.0 + saturation * 3.0;
        let key = ((r as u16 >> 4) << 8) | ((g as u16 >> 4) << 4) | (b as u16 >> 4);
        let bin = bins.entry(key).or_insert((0.0, [0.0; 3]));
        bin.0 += weight;
        for (sum, channel) in bin.1.iter_mut().zip([r, g, b]) {
            *sum += channel as f64 * weight;
        }
    }
    let mut ranked: Vec<(f64, [f64; 3])> = bins.into_values().map(|(w, sum)| (w, [sum[0] / w, sum[1] / w, sum[2] / w])).collect();
    ranked.sort_by(|a, b| b.0.total_cmp(&a.0));
    let mut picked: Vec<[f64; 3]> = Vec::new();
    for (_, c) in &ranked {
        let distinct = picked.iter().all(|p| (p[0] - c[0]).abs() + (p[1] - c[1]).abs() + (p[2] - c[2]).abs() > 90.0);
        if distinct {
            picked.push(*c);
            if picked.len() == 3 {
                break;
            }
        }
    }
    let first = *picked.first()?;
    while picked.len() < 3 {
        picked.push(first);
    }
    Some(picked.into_iter().map(hex).collect())
}

async fn fetch_art(url: String) {
    let dir = util::dirs().cache.join("art");
    util::ensure_dir(&dir);
    let local: Option<PathBuf> = if let Some(p) = url.strip_prefix("file://") {
        Some(PathBuf::from(url_decode(p)))
    } else if url.starts_with('/') {
        Some(PathBuf::from(&url))
    } else if url.starts_with("http://") || url.starts_with("https://") {
        let target = dir.join(util::hash_str(&url));
        if !target.exists() {
            let (u, t) = (url.clone(), target.clone());
            let fetched = tokio::task::spawn_blocking(move || -> Result<()> {
                let mut data = Vec::new();
                use std::io::Read;
                ureq::get(&u).timeout(Duration::from_secs(10)).call()?.into_reader().take(20 << 20).read_to_end(&mut data)?;
                util::write_atomic(&t, &data)
            })
            .await;
            if !matches!(fetched, Ok(Ok(()))) {
                log!("could not download album art from {url}");
            }
        }
        target.exists().then_some(target)
    } else {
        None
    };
    let art = match local.filter(|p| p.exists()) {
        Some(path) => {
            let p = path.clone();
            let colours = tokio::task::spawn_blocking(move || palette(&p)).await.ok().flatten().unwrap_or_default();
            Some(Art { path: path.to_string_lossy().into_owned(), palette: colours })
        }
        // Remember the failure too, so a broken URL is not retried on every refresh.
        None => Some(Art { path: String::new(), palette: Vec::new() }),
    };
    d().media.art.lock().unwrap().insert(url, art);
    d().media.dirty.notify_one();
}

/// The art for `url` if ready; otherwise start fetching it and return nothing for now.
fn art_for(url: &str) -> Option<Art> {
    if url.is_empty() {
        return None;
    }
    let mut cache = d().media.art.lock().unwrap();
    match cache.get(url) {
        Some(art) => art.clone(),
        None => {
            if cache.len() > 200 {
                cache.clear();
            }
            cache.insert(url.to_string(), None);
            tokio::spawn(fetch_art(url.to_string()));
            None
        }
    }
}

// ---------------------------------------------------------------- players

async fn refresh() -> Result<()> {
    let conn = dbus::session().await?;
    let m = &d().media;
    let reply = conn.call_method(Some("org.freedesktop.DBus"), "/org/freedesktop/DBus", Some("org.freedesktop.DBus"), "ListNames", &()).await?;
    let names: Vec<String> = reply.body().deserialize()?;

    let mut players = Vec::new();
    for bus in names.iter().filter(|n| n.starts_with(PREFIX)) {
        // playerctld only mirrors another player; listing it would duplicate that player.
        if bus.ends_with(".playerctld") {
            continue;
        }
        let Ok(p) = dbus::get_all(&conn, bus, PATH, PLAYER).await else { continue };
        let root = dbus::get_all(&conn, bus, PATH, ROOT).await.unwrap_or(Value::Null);
        let meta = &p["Metadata"];
        let status = p["PlaybackStatus"].as_str().unwrap_or("Stopped").to_string();
        let title = meta["xesam:title"].as_str().unwrap_or("").to_string();
        let artist = match &meta["xesam:artist"] {
            Value::Array(a) => a.iter().filter_map(Value::as_str).collect::<Vec<_>>().join(", "),
            Value::String(s) => s.clone(),
            _ => String::new(),
        };
        let key = format!("{status}|{title}");
        let changed = {
            let mut memo = m.memo.lock().unwrap();
            let entry = memo.entry(bus.clone()).or_insert_with(|| (String::new(), 0));
            if entry.0 != key {
                *entry = (key, util::now_ms());
            }
            entry.1
        };
        let name = root["Identity"].as_str().map(String::from).unwrap_or_else(|| bus[PREFIX.len()..].split('.').next().unwrap_or("").to_string());
        players.push(json!({
            "id": bus, "name": name, "desktopEntry": root["DesktopEntry"], "status": status, "title": title, "artist": artist,
            "album": meta["xesam:album"].as_str().unwrap_or(""),
            "length": meta["mpris:length"].as_f64().unwrap_or(0.0) / 1e6,
            "position": p["Position"].as_f64().unwrap_or(0.0) / 1e6,
            "rate": p["Rate"].as_f64().unwrap_or(1.0),
            "artUrl": meta["mpris:artUrl"].as_str().unwrap_or(""),
            "trackId": meta["mpris:trackid"].as_str().unwrap_or(""),
            "canSeek": p["CanSeek"].as_bool().unwrap_or(false),
            "canNext": p["CanGoNext"].as_bool().unwrap_or(true),
            "canPrev": p["CanGoPrevious"].as_bool().unwrap_or(true),
            "changed": changed,
        }));
    }
    m.memo.lock().unwrap().retain(|bus, _| names.contains(bus));

    // Current player: the user's pick if it still exists, else whatever started
    // playing most recently, else the most recently paused one.
    let selected = m.selected.lock().unwrap().clone();
    let rank = |p: &Value| {
        let tier = match p["status"].as_str() {
            _ if p["id"].as_str() == Some(&selected) && !selected.is_empty() => 3,
            Some("Playing") => 2,
            Some("Paused") if !p["title"].as_str().unwrap_or("").is_empty() => 1,
            _ => 0,
        };
        (tier, p["changed"].as_u64().unwrap_or(0))
    };
    let active = players.iter().max_by_key(|p| rank(p)).filter(|p| rank(p).0 > 0).cloned().unwrap_or(Value::Null);
    *m.active.lock().unwrap() = active.clone();

    let art = art_for(active["artUrl"].as_str().unwrap_or(""));
    let list: Vec<Value> = players
        .iter()
        .map(|p| {
            let icon = d().apps.icon_for(&[p["desktopEntry"].as_str().unwrap_or(""), p["name"].as_str().unwrap_or("")]).unwrap_or_default();
            json!({ "id": p["id"], "name": p["name"], "status": p["status"], "title": p["title"], "icon": icon })
        })
        .collect();
    let mut state = json!({ "available": !active.is_null(), "players": list, "status": "Stopped", "title": "", "artist": "", "album": "", "length": 0, "position": 0, "art": "", "palette": [] });
    if let (Some(state), Some(active)) = (state.as_object_mut(), active.as_object()) {
        for (k, v) in active {
            if k != "changed" && k != "artUrl" {
                state.insert(k.clone(), v.clone());
            }
        }
        state.insert("positionAt".into(), json!(util::now_ms()));
        if let Some(art) = art {
            state.insert("art".into(), json!(art.path));
            state.insert("palette".into(), json!(art.palette));
        }
    }
    d().hub.publish("media", &state);
    Ok(())
}

pub async fn run() -> Result<()> {
    eq_publish();
    let offline = json!({ "available": false, "players": [], "status": "Stopped", "title": "", "artist": "", "album": "", "length": 0, "position": 0, "art": "", "palette": [] });
    let conn = match dbus::session().await {
        Ok(c) => c,
        Err(e) => {
            log!("session bus unavailable ({e:#}); media disabled");
            d().hub.publish("media", &offline);
            return Ok(());
        }
    };
    let c = conn.clone();
    tokio::spawn(async move {
        let rule = zbus::MatchRule::builder().msg_type(zbus::message::Type::Signal).path(PATH).expect("static path").build();
        let _ = dbus::watch_rule(&c, rule, |_, _, _, _| d().media.dirty.notify_one()).await;
    });
    tokio::spawn(async move {
        let rule = zbus::MatchRule::builder()
            .msg_type(zbus::message::Type::Signal)
            .sender("org.freedesktop.DBus")
            .and_then(|r| r.member("NameOwnerChanged"))
            .and_then(|r| r.arg0ns(ROOT))
            .expect("static rule")
            .build();
        let _ = dbus::watch_rule(&conn, rule, |_, _, _, _| d().media.dirty.notify_one()).await;
    });
    // Players do not announce position changes, so re-read it now and then while playing.
    tokio::spawn(async {
        loop {
            tokio::time::sleep(Duration::from_secs(4)).await;
            if d().media.active.lock().unwrap()["status"] == "Playing" {
                d().media.dirty.notify_one();
            }
        }
    });
    loop {
        if let Err(e) = refresh().await {
            log!("media refresh: {e:#}");
        }
        d().media.dirty.notified().await;
        tokio::time::sleep(Duration::from_millis(50)).await;
    }
}

pub async fn call(name: &str, p: &Value) -> Result<Value> {
    let m = &d().media;
    if name == "select" {
        *m.selected.lock().unwrap() = p.str("id")?.to_string();
        m.dirty.notify_one();
        return Ok(Value::Null);
    }
    let active = m.active.lock().unwrap().clone();
    let bus = p.get("player").and_then(Value::as_str).or(active["id"].as_str()).ok_or_else(|| anyhow!("no media player is running"))?.to_string();
    let conn = dbus::session().await?;
    match name {
        "playPause" => conn.call_method(Some(bus.as_str()), PATH, Some(PLAYER), "PlayPause", &()).await?,
        "next" => conn.call_method(Some(bus.as_str()), PATH, Some(PLAYER), "Next", &()).await?,
        "previous" => conn.call_method(Some(bus.as_str()), PATH, Some(PLAYER), "Previous", &()).await?,
        "seek" => {
            let target = (p.num("position")? * 1e6) as i64;
            match active["trackId"].as_str().filter(|t| t.starts_with('/')).and_then(|t| ObjectPath::try_from(t).ok()) {
                Some(track) => conn.call_method(Some(bus.as_str()), PATH, Some(PLAYER), "SetPosition", &(track, target)).await?,
                // Without a track id only relative seeking is possible.
                None => {
                    let elapsed = if active["status"] == "Playing" { (util::now_ms() as f64 - active["positionAt"].as_f64().unwrap_or(util::now_ms() as f64)) * 1e3 } else { 0.0 };
                    let current = (active["position"].as_f64().unwrap_or(0.0) * 1e6 + elapsed) as i64;
                    conn.call_method(Some(bus.as_str()), PATH, Some(PLAYER), "Seek", &(target - current,)).await?
                }
            }
        }
        _ => bail!("unknown method media.{name}"),
    };
    m.dirty.notify_one();
    Ok(Value::Null)
}

// ---------------------------------------------------------------- equalizer (EasyEffects)

const BANDS_HZ: [f64; 10] = [31.0, 63.0, 125.0, 250.0, 500.0, 1000.0, 2000.0, 4000.0, 8000.0, 16000.0];
const PRESETS: [(&str, [f64; 10]); 8] = [
    ("Flat", [0.0; 10]),
    ("Bass", [5.0, 7.0, 5.0, 2.0, 1.0, 0.0, 0.0, 0.0, 1.0, 2.0]),
    ("Treble", [-2.0, -1.0, 0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 6.0]),
    ("Vocal", [-2.0, -1.0, 1.0, 3.0, 5.0, 5.0, 4.0, 2.0, 1.0, 0.0]),
    ("Pop", [2.0, 4.0, 2.0, 0.0, 1.0, 2.0, 4.0, 2.0, 1.0, 2.0]),
    ("Rock", [5.0, 4.0, 2.0, -1.0, -2.0, -1.0, 2.0, 4.0, 5.0, 6.0]),
    ("Jazz", [3.0, 3.0, 1.0, 1.0, 1.0, 1.0, 2.0, 1.0, 2.0, 3.0]),
    ("Classic", [0.0, 1.0, 2.0, 2.0, 2.0, 2.0, 1.0, 2.0, 3.0, 4.0]),
];

#[derive(Clone)]
struct Eq {
    bands: [f64; 10],
    preset: String,
    /// Bands were edited but not yet sent to EasyEffects.
    pending: bool,
}

fn eq_file() -> PathBuf {
    util::dirs().state.join("equalizer.json")
}

fn eq_state() -> Eq {
    let mut guard = d().media.eq.lock().unwrap();
    guard
        .get_or_insert_with(|| {
            let saved = util::read_json(&eq_file()).unwrap_or(Value::Null);
            let mut bands = [0.0; 10];
            for (i, b) in bands.iter_mut().enumerate() {
                *b = saved["bands"][i].as_f64().unwrap_or(0.0);
            }
            Eq { bands, preset: saved["preset"].as_str().unwrap_or("Flat").to_string(), pending: false }
        })
        .clone()
}

fn eq_store(eq: Eq) {
    let _ = util::write_json(&eq_file(), &json!({ "bands": eq.bands, "preset": eq.preset }));
    *d().media.eq.lock().unwrap() = Some(eq);
    eq_publish();
}

fn eq_publish() {
    let eq = eq_state();
    let presets: serde_json::Map<String, Value> = PRESETS.iter().map(|(n, b)| (n.to_string(), json!(b))).collect();
    let names: Vec<&str> = PRESETS.iter().map(|(name, _)| *name).collect();
    d().hub.publish("eq", &json!({ "available": util::which("easyeffects"), "bands": eq.bands, "preset": eq.preset, "pending": eq.pending, "frequencies": BANDS_HZ, "presets": presets, "presetNames": names }));
}

/// Write the bands as an EasyEffects output preset and ask EasyEffects to load it.
async fn eq_apply(eq: &Eq) -> Result<()> {
    if !util::which("easyeffects") {
        bail!("EasyEffects is not installed");
    }
    let band = |i: usize| json!({ "frequency": BANDS_HZ[i], "gain": eq.bands[i], "mode": "RLC (BT)", "mute": false, "q": 1.5, "slope": "x1", "solo": false, "type": "Bell", "width": 4.0 });
    let channel: serde_json::Map<String, Value> = (0..10).map(|i| (format!("band{i}"), band(i))).collect();
    let preset = json!({ "output": {
        "blocklist": [],
        "equalizer#0": {
            "balance": 0.0, "bypass": false, "input-gain": 0.0, "output-gain": 0.0, "mode": "IIR", "num-bands": 10,
            "pitch-left": 0.0, "pitch-right": 0.0, "split-channels": false, "left": channel.clone(), "right": channel,
        },
        "plugins_order": ["equalizer#0"],
    }});
    // EasyEffects 8 keeps presets in the data directory, older versions in the config directory.
    let data = util::home().join(".local/share/easyeffects");
    let dir = if data.exists() { data.join("output") } else { util::home().join(".config/easyeffects/output") };
    util::write_json(&dir.join("fableland.json"), &preset)?;
    util::run("easyeffects", &["-l", "fableland"]).await?;
    Ok(())
}

pub async fn eq_call(name: &str, p: &Value) -> Result<Value> {
    let mut eq = eq_state();
    match name {
        "setBand" => {
            let i = p.int("index")?.clamp(0, 9) as usize;
            eq.bands[i] = p.num("gain")?.clamp(-12.0, 12.0).round();
            eq.preset = "Custom".into();
            eq.pending = true;
        }
        "preset" => {
            let wanted = p.str("name")?;
            let (label, bands) = PRESETS.iter().find(|(n, _)| *n == wanted).ok_or_else(|| anyhow!("unknown preset '{wanted}'"))?;
            eq.bands = *bands;
            eq.preset = label.to_string();
            eq.pending = false;
            eq_apply(&eq).await?;
        }
        "apply" => {
            eq.pending = false;
            eq_apply(&eq).await?;
        }
        _ => bail!("unknown method eq.{name}"),
    }
    eq_store(eq);
    Ok(Value::Null)
}
