//! The desktop notification server (org.freedesktop.Notifications).
//!
//! Living in the daemon means history, do-not-disturb and pending actions
//! survive UI restarts. The `notif` topic holds the history; a `notif.new`
//! event asks the UI to pop a toast.

use crate::util::Params;
use crate::{d, dbus, features, log, util};
use anyhow::{bail, Result};
use serde_json::{json, Value};
use std::collections::HashMap;
use std::sync::atomic::{AtomicU32, Ordering};
use std::sync::Mutex;
use zbus::zvariant::{OwnedValue, Value as V};

const NAME: &str = "org.freedesktop.Notifications";
const OBJECT: &str = "/org/freedesktop/Notifications";
const HISTORY_LIMIT: usize = 100;

#[derive(Default)]
pub struct Notif {
    items: Mutex<Vec<Value>>,
    next_id: AtomicU32,
    /// Notifications raised by the daemon itself: id → (action id → shell command).
    own_actions: Mutex<HashMap<u32, HashMap<String, String>>>,
}

fn image_dir() -> std::path::PathBuf {
    let dir = util::dirs().run.join("notifications");
    util::ensure_dir(&dir);
    dir
}

/// Decode the raw `image-data` hint (iiibiiay) into a PNG file.
fn save_image_data(v: &V, id: u32) -> Option<String> {
    let V::Structure(s) = v else { return None };
    let f = s.fields();
    let int = |i: usize| if let Some(V::I32(n)) = f.get(i) { *n as usize } else { 0 };
    let (width, height, stride, channels) = (int(0), int(1), int(2), int(5));
    let data = dbus::bytes(f.get(6)?)?;
    if width == 0 || height == 0 || !(channels == 3 || channels == 4) || data.len() < stride * (height - 1) + width * channels {
        return None;
    }
    let mut pixels = Vec::with_capacity(width * height * channels);
    for row in 0..height {
        let start = row * stride;
        pixels.extend_from_slice(&data[start..start + width * channels]);
    }
    let color = if channels == 4 { image::ColorType::Rgba8 } else { image::ColorType::Rgb8 };
    let path = image_dir().join(format!("{id}.png"));
    image::save_buffer(&path, &pixels, width as u32, height as u32, color).ok()?;
    Some(path.to_string_lossy().into_owned())
}

fn strip_file_url(s: &str) -> &str {
    s.strip_prefix("file://").unwrap_or(s)
}

fn publish() {
    let n = &d().notif;
    d().hub.publish("notif", &json!({ "dnd": d().settings.flag("notifications.dnd"), "items": *n.items.lock().unwrap() }));
}

/// Record a notification and show it (subject to do-not-disturb).
fn post(mut item: Value, transient: bool) {
    let n = &d().notif;
    let id = item["id"].as_u64().unwrap_or(0);
    item["time"] = json!(util::now_ms());
    if !transient {
        let mut items = n.items.lock().unwrap();
        items.retain(|i| i["id"].as_u64() != Some(id));
        items.insert(0, item.clone());
        let keep = HISTORY_LIMIT.min(items.len());
        for old in items.drain(keep..) {
            let _ = std::fs::remove_file(image_dir().join(format!("{}.png", old["id"])));
        }
    }
    publish();
    let critical = item["urgency"].as_u64() == Some(2);
    if critical || !d().settings.flag("notifications.dnd") {
        d().hub.emit("notif.new", &item);
    }
}

struct Server;

#[zbus::interface(name = "org.freedesktop.Notifications")]
impl Server {
    async fn get_capabilities(&self) -> Vec<&'static str> {
        vec!["body", "body-markup", "body-hyperlinks", "actions", "icon-static", "persistence"]
    }

    #[allow(clippy::too_many_arguments)]
    async fn notify(&self, app_name: String, replaces_id: u32, app_icon: String, summary: String, body: String, actions: Vec<String>, hints: HashMap<String, OwnedValue>, expire_timeout: i32) -> u32 {
        let n = &d().notif;
        let id = if replaces_id != 0 { replaces_id } else { n.next_id.fetch_add(1, Ordering::Relaxed) + 1 };
        let hint = |keys: &[&str]| keys.iter().find_map(|k| hints.get(*k));
        let hint_str = |keys: &[&str]| hint(keys).and_then(|v| if let V::Str(s) = &**v { Some(s.to_string()) } else { None });

        let urgency = hint(&["urgency"]).map(|v| dbus::to_json(v)).and_then(|v| v.as_u64()).unwrap_or(1);
        let mut image = hint(&["image-data", "image_data", "icon_data"]).and_then(|v| save_image_data(v, id)).unwrap_or_default();
        if image.is_empty() {
            image = hint_str(&["image-path", "image_path"]).map(|p| strip_file_url(&p).to_string()).unwrap_or_default();
        }
        let mut icon = strip_file_url(&app_icon).to_string();
        // An icon given as a file is really a picture.
        if image.is_empty() && icon.starts_with('/') {
            image = std::mem::take(&mut icon);
        }
        let actions: Vec<Value> = actions.chunks(2).filter(|c| c.len() == 2).map(|c| json!({ "id": c[0], "label": c[1] })).collect();
        let timeout = match expire_timeout {
            0 => 0,
            t if t > 0 => t as i64,
            // Critical notifications stay until dismissed.
            _ if urgency == 2 => 0,
            _ => d().settings.num("notifications.timeoutMs") as i64,
        };
        let transient = hint(&["transient"]).map(|v| dbus::to_json(v)).is_some_and(|v| v == true || v == 1);
        post(
            json!({
                "id": id,
                "app": if app_name.is_empty() { "System".to_string() } else { app_name },
                "summary": summary, "body": body, "icon": icon, "image": image,
                "urgency": urgency, "actions": actions, "timeout": timeout,
                "desktopEntry": hint_str(&["desktop-entry"]).unwrap_or_default(),
            }),
            transient,
        );
        id
    }

    async fn close_notification(&self, id: u32) {
        remove(|i| i["id"].as_u64() == Some(id as u64), 3).await;
    }

    async fn get_server_information(&self) -> (&'static str, &'static str, &'static str, &'static str) {
        ("fableland", "fableland", env!("CARGO_PKG_VERSION"), "1.2")
    }
}

async fn signal<B: serde::Serialize + zbus::zvariant::DynamicType>(name: &str, body: &B) {
    if let Ok(conn) = dbus::session().await {
        let _ = conn.emit_signal(None::<&str>, OBJECT, NAME, name, body).await;
    }
}

/// Drop every notification matching `pred` and tell the sender it was closed
/// (reason 2 = dismissed by the user, 3 = closed by the application).
async fn remove(pred: impl Fn(&Value) -> bool, reason: u32) {
    let n = &d().notif;
    let removed: Vec<Value> = {
        let mut items = n.items.lock().unwrap();
        let (gone, kept): (Vec<Value>, Vec<Value>) = std::mem::take(&mut *items).into_iter().partition(|i| pred(i));
        *items = kept;
        gone
    };
    for item in &removed {
        let id = item["id"].as_u64().unwrap_or(0) as u32;
        n.own_actions.lock().unwrap().remove(&id);
        let _ = std::fs::remove_file(image_dir().join(format!("{id}.png")));
        d().hub.emit("notif.closed", &json!({ "id": id }));
        signal("NotificationClosed", &(id, reason)).await;
    }
    publish();
}

/// A notification raised by the daemon itself.
pub struct Note<'a> {
    pub app: &'a str,
    pub summary: &'a str,
    pub body: &'a str,
    pub icon: &'a str,
    pub image: &'a str,
    /// (label, shell command run when chosen). The first one is the default action.
    pub actions: Vec<(&'a str, String)>,
}

/// Hand a notification of the daemon's own to whoever serves notifications
/// instead of this module. Its actions stay behind: they are commands only the
/// daemon could run.
async fn forward(app: String, summary: String, body: String, icon: String, image: String) -> Result<()> {
    let hints: HashMap<&str, V> = if image.is_empty() { HashMap::new() } else { HashMap::from([("image-path", V::from(image))]) };
    let no_actions: [&str; 0] = [];
    dbus::session().await?.call_method(Some(NAME), OBJECT, Some(NAME), "Notify", &(app, 0u32, icon, summary, body, no_actions.as_slice(), hints, -1i32)).await?;
    Ok(())
}

pub fn notify(note: Note) {
    if !features::on("notifications") {
        let sent = forward(note.app.into(), note.summary.into(), note.body.into(), note.icon.into(), note.image.into());
        tokio::spawn(async {
            if let Err(e) = sent.await {
                log!("could not pass a notification on: {e:#}");
            }
        });
        return;
    }
    let n = &d().notif;
    let id = n.next_id.fetch_add(1, Ordering::Relaxed) + 1;
    let mut commands = HashMap::new();
    let actions: Vec<Value> = note
        .actions
        .iter()
        .enumerate()
        .map(|(i, (label, command))| {
            let key = if i == 0 { "default".to_string() } else { format!("action{i}") };
            commands.insert(key.clone(), command.clone());
            json!({ "id": key, "label": label })
        })
        .collect();
    n.own_actions.lock().unwrap().insert(id, commands);
    post(
        json!({
            "id": id, "app": note.app, "summary": note.summary, "body": note.body, "icon": note.icon, "image": note.image,
            "urgency": 1, "actions": actions, "timeout": d().settings.num("notifications.timeoutMs") as i64, "desktopEntry": "",
        }),
        false,
    );
}

pub async fn run() -> Result<()> {
    publish();
    // React to do-not-disturb being flipped in settings.
    tokio::spawn(async {
        let mut rx = d().settings.changes();
        while rx.changed().await.is_ok() {
            publish();
        }
    });
    let conn = dbus::session().await?;
    conn.object_server().at(OBJECT, Server).await?;
    // Queue behind an existing notification daemon instead of fighting it; we take over when it exits.
    match conn.request_name_with_flags(NAME, zbus::fdo::RequestNameFlags::AllowReplacement.into()).await {
        Ok(zbus::fdo::RequestNameReply::PrimaryOwner) | Ok(zbus::fdo::RequestNameReply::AlreadyOwner) => {}
        Ok(_) => log!("another notification daemon is running; notifications will arrive here once it exits"),
        Err(e) => log!("could not register the notification service: {e}"),
    }
    std::future::pending::<()>().await;
    Ok(())
}

pub async fn call(name: &str, p: &Value) -> Result<Value> {
    let n = &d().notif;
    match name {
        "dismiss" => {
            let id = p.int("id")? as u64;
            remove(|i| i["id"].as_u64() == Some(id), 2).await;
        }
        "dismissApp" => {
            let app = p.str("app")?.to_string();
            remove(|i| i["app"].as_str() == Some(&app), 2).await;
        }
        "clear" => remove(|_| true, 2).await,
        "invoke" => {
            let id = p.int("id")? as u32;
            let action = p.str_or("action", "default").to_string();
            let own = n.own_actions.lock().unwrap().get(&id).and_then(|a| a.get(&action).cloned());
            match own {
                Some(command) => util::spawn_detached("sh", &["-c", &command]),
                None => signal("ActionInvoked", &(id, action.as_str())).await,
            }
            remove(|i| i["id"].as_u64() == Some(id as u64), 2).await;
        }
        "setDnd" => d().settings.set("notifications.dnd", json!(p.flag("on")?))?,
        "test" => {
            notify(Note {
                app: p.str_or("app", "Fableland"),
                summary: p.str_or("summary", "Hello from the daemon"),
                body: p.str_or("body", "Notifications are <b>working</b>."),
                icon: p.str_or("icon", "dialog-information"),
                image: "",
                actions: vec![("Open home folder", "xdg-open ~".into())],
            });
        }
        _ => bail!("unknown method notif.{name}"),
    }
    Ok(Value::Null)
}
