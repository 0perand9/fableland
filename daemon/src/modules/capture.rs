//! Screenshots and screen recording (`capture` topic).
//!
//! Region screenshots work on a frozen frame: the monitor is grabbed first, the
//! UI lets the user select on that still image, and the selection is cropped out
//! of it here. What you select is exactly what you get, menus and tooltips included.

use super::notif::{self, Note};
use crate::util::Params;
use crate::{d, log, util};
use anyhow::{anyhow, bail, Context, Result};
use chrono::Local;
use serde_json::{json, Value};
use std::path::{Path, PathBuf};
use std::sync::Mutex;
use std::time::Duration;

#[derive(Default)]
pub struct Capture {
    /// (pid, output file, start time in ms) of the running recorder.
    recording: Mutex<Option<(u32, PathBuf, u64)>>,
}

fn publish() {
    let rec = d().capture.recording.lock().unwrap().clone();
    d().hub.publish(
        "capture",
        &json!({
            "recording": match rec {
                Some((_, file, since)) => json!({ "active": true, "file": file.to_string_lossy(), "since": since }),
                None => json!({ "active": false }),
            },
            "tools": {
                "screenshot": util::which("grim"), "record": util::which("wf-recorder"),
                "edit": editor().is_some(), "ocr": util::which("tesseract"), "qr": util::which("zbarimg"),
            },
        }),
    );
}

fn editor() -> Option<&'static str> {
    let preferred = d().settings.str("capture.editor");
    ["satty", "swappy"].into_iter().filter(|e| util::which(e)).max_by_key(|e| *e == preferred)
}

fn freeze_file() -> PathBuf {
    util::dirs().run.join("freeze.ppm")
}

fn stamp() -> String {
    Local::now().format("%Y-%m-%d_%H-%M-%S").to_string()
}

fn out_dir(setting: &str) -> Result<PathBuf> {
    let dir = util::expand(&d().settings.str(setting));
    std::fs::create_dir_all(&dir).with_context(|| format!("cannot create {}", dir.display()))?;
    Ok(dir)
}

/// The monitor the pointer/focus is on, from the `monitors` topic.
fn monitor(name: Option<&str>) -> Result<Value> {
    let monitors = d().hub.get("monitors").unwrap_or(Value::Null);
    let list = monitors.as_array().ok_or_else(|| anyhow!("no monitor information"))?;
    list.iter()
        .find(|m| match name {
            Some(n) if !n.is_empty() => m["name"].as_str() == Some(n),
            _ => m["focused"] == true,
        })
        .or(list.first())
        .cloned()
        .ok_or_else(|| anyhow!("no monitor found"))
}

fn encode_png(img: &image::RgbImage) -> Result<Vec<u8>> {
    use image::ImageEncoder;
    let mut out = Vec::new();
    // Fast compression: a screenshot should land on the clipboard without a noticeable pause.
    image::codecs::png::PngEncoder::new_with_quality(&mut out, image::codecs::png::CompressionType::Fast, image::codecs::png::FilterType::Adaptive)
        .write_image(img.as_raw(), img.width(), img.height(), image::ExtendedColorType::Rgb8)?;
    Ok(out)
}

fn folder_action(dir: &Path) -> (&'static str, String) {
    ("Open folder", format!("xdg-open '{}'", dir.display()))
}

/// Deliver a finished screenshot according to `action`.
async fn finish(png: Vec<u8>, action: &str) -> Result<()> {
    let dir = out_dir("capture.dir")?;
    let file = dir.join(format!("Screenshot_{}.png", stamp()));
    let file_str = file.to_string_lossy().into_owned();
    match action {
        "edit" => {
            let tool = editor().ok_or_else(|| anyhow!("install satty or swappy to annotate screenshots"))?;
            let args: Vec<&str> = if tool == "satty" { vec!["--filename", "-", "--output-filename", &file_str, "--copy-command", "wl-copy", "--init-tool", "brush", "--early-exit"] } else { vec!["-f", "-", "-o", &file_str] };
            let args: Vec<String> = args.into_iter().map(String::from).collect();
            // The editor outlives this request; it saves and copies on its own.
            tokio::spawn(async move {
                let refs: Vec<&str> = args.iter().map(String::as_str).collect();
                if let Err(e) = util::run_with_input(tool, &refs, &png).await {
                    log!("screenshot editor: {e:#}");
                }
            });
        }
        "ocr" => {
            if !util::which("tesseract") {
                bail!("install tesseract to read text from the screen");
            }
            let text = String::from_utf8_lossy(&util::run_with_input("tesseract", &["stdin", "stdout"], &png).await?).trim().to_string();
            if text.is_empty() {
                bail!("no text found in the selection");
            }
            super::clipboard::copy_bytes(text.as_bytes(), None).await?;
            notif::notify(Note { app: "Screenshot", summary: "Text copied", body: &text.chars().take(300).collect::<String>(), icon: "edit-copy", image: "", actions: vec![] });
        }
        "qr" => {
            if !util::which("zbarimg") {
                bail!("install zbar (zbarimg) to scan QR codes");
            }
            let found = util::run_with_input("zbarimg", &["-q", "--raw", "-"], &png).await.map_err(|_| anyhow!("no QR code found in the selection"))?;
            let text = String::from_utf8_lossy(&found).trim().to_string();
            super::clipboard::copy_bytes(text.as_bytes(), None).await?;
            let actions = if text.starts_with("http://") || text.starts_with("https://") { vec![("Open link", format!("xdg-open '{}'", text.replace('\'', "")))] } else { vec![] };
            notif::notify(Note { app: "Screenshot", summary: "QR code copied", body: &text, icon: "edit-copy", image: "", actions });
        }
        _ => {
            std::fs::write(&file, &png)?;
            super::clipboard::copy_bytes(&png, Some("image/png")).await?;
            let name = file.file_name().map(|n| n.to_string_lossy().into_owned()).unwrap_or_default();
            notif::notify(Note { app: "Screenshot", summary: "Screenshot saved", body: &name, icon: "camera-photo", image: &file_str, actions: vec![folder_action(&dir)] });
        }
    }
    Ok(())
}

/// Begin a capture: grab the frame and hand over to the selection overlay, or shoot directly.
/// `on` names the monitor; without it the focused one is taken.
async fn start(mode: &str, on: Option<&str>) -> Result<()> {
    match mode {
        "stop" => return stop_recording().await,
        "record" => {
            if d().capture.recording.lock().unwrap().is_some() {
                return stop_recording().await;
            }
            if !util::which("wf-recorder") {
                bail!("install wf-recorder to record the screen");
            }
            let m = monitor(on)?;
            d().hub.emit("capture", &json!({ "mode": "record", "monitor": m["name"], "image": "" }));
            return Ok(());
        }
        _ => {}
    }
    if !util::which("grim") {
        bail!("install grim to take screenshots");
    }
    // Say what is missing now rather than after the user has selected a region.
    match mode {
        "edit" if editor().is_none() => bail!("install satty or swappy to edit screenshots"),
        "ocr" if !util::which("tesseract") => bail!("install tesseract to read text from the screen"),
        "qr" if !util::which("zbarimg") => bail!("install zbar (zbarimg) to scan QR codes"),
        _ => {}
    }
    let m = monitor(on)?;
    let name = m["name"].as_str().unwrap_or("").to_string();
    if mode == "full" {
        let png = tokio::process::Command::new("grim").args(["-l", "1", "-o", &name, "-"]).output().await?;
        if !png.status.success() {
            bail!("grim failed: {}", String::from_utf8_lossy(&png.stderr).trim());
        }
        return finish(png.stdout, "copy").await;
    }
    // Uncompressed PPM: grabbing must be instant, and the file lives on tmpfs anyway.
    let freeze = freeze_file();
    util::run("grim", &["-t", "ppm", "-o", &name, &freeze.to_string_lossy()]).await?;
    let action = if matches!(mode, "edit" | "ocr" | "qr") { mode } else { "copy" };
    d().hub.emit("capture", &json!({ "mode": "image", "action": action, "monitor": name, "image": freeze.to_string_lossy(), "stamp": util::now_ms() }));
    Ok(())
}

/// Crop the frozen frame. Coordinates are in the overlay's units; `viewWidth` is
/// the overlay's width, which gives the factor to physical pixels.
async fn shot(p: &Value) -> Result<()> {
    let (x, y, w, h) = (p.num("x")?, p.num("y")?, p.num("w")?, p.num("h")?);
    let view_width = p.num("viewWidth")?.max(1.0);
    let action = p.str_or("action", "copy").to_string();
    let png = tokio::task::spawn_blocking(move || -> Result<Vec<u8>> {
        let frame = image::open(freeze_file()).context("the frozen frame is gone")?.to_rgb8();
        let scale = frame.width() as f64 / view_width;
        let px = |v: f64| (v * scale).round().max(0.0) as u32;
        let (cx, cy) = (px(x).min(frame.width().saturating_sub(1)), px(y).min(frame.height().saturating_sub(1)));
        let (cw, ch) = (px(w).clamp(1, frame.width() - cx), px(h).clamp(1, frame.height() - cy));
        encode_png(&image::imageops::crop_imm(&frame, cx, cy, cw, ch).to_image())
    })
    .await??;
    let _ = std::fs::remove_file(freeze_file());
    finish(png, &action).await
}

async fn record(p: &Value) -> Result<()> {
    if d().capture.recording.lock().unwrap().is_some() {
        bail!("a recording is already running");
    }
    let m = monitor(p.get("monitor").and_then(Value::as_str))?;
    // wf-recorder wants global layout coordinates.
    let (gx, gy) = (m["x"].as_f64().unwrap_or(0.0) + p.num("x")?, m["y"].as_f64().unwrap_or(0.0) + p.num("y")?);
    let geometry = format!("{},{} {}x{}", gx.round() as i64, gy.round() as i64, p.num("w")?.round().max(2.0) as i64, p.num("h")?.round().max(2.0) as i64);
    let file = out_dir("capture.videoDir")?.join(format!("Recording_{}.mp4", stamp()));
    let file_str = file.to_string_lossy().into_owned();
    let mut args = vec!["-g".to_string(), geometry, "-f".to_string(), file_str];
    let audio = d().hub.get("audio").unwrap_or(Value::Null);
    match p.str_or("audio", &d().settings.str("capture.audio")) {
        "desktop" => {
            if let Some(sink) = audio["sink"]["name"].as_str() {
                args.push(format!("--audio={sink}.monitor"));
            }
        }
        "mic" => {
            if let Some(source) = audio["source"]["name"].as_str() {
                args.push(format!("--audio={source}"));
            }
        }
        _ => {}
    }
    let refs: Vec<&str> = args.iter().map(String::as_str).collect();
    let child = util::spawn("wf-recorder", &refs)?;
    let pid = child.id().ok_or_else(|| anyhow!("recorder exited immediately"))?;
    *d().capture.recording.lock().unwrap() = Some((pid, file, util::now_ms()));
    publish();
    // If the recorder dies on its own (bad geometry, encoder error), reflect that.
    tokio::spawn(async move {
        let mut child = child;
        let _ = child.wait().await;
        let ours = d().capture.recording.lock().unwrap().as_ref().is_some_and(|r| r.0 == pid);
        if ours {
            finish_recording().await;
        }
    });
    Ok(())
}

async fn finish_recording() {
    let Some((_, file, _)) = d().capture.recording.lock().unwrap().take() else { return };
    publish();
    let dir = file.parent().map(Path::to_path_buf).unwrap_or_default();
    let name = file.file_name().map(|n| n.to_string_lossy().into_owned()).unwrap_or_default();
    if std::fs::metadata(&file).map(|m| m.len() > 0).unwrap_or(false) {
        notif::notify(Note { app: "Screen recorder", summary: "Recording saved", body: &name, icon: "media-record", image: "", actions: vec![folder_action(&dir), ("Play", format!("xdg-open '{}'", file.display()))] });
    } else {
        d().hub.toast("error", "Screen recorder", "The recording could not be saved.");
    }
}

async fn stop_recording() -> Result<()> {
    let pid = d().capture.recording.lock().unwrap().as_ref().map(|r| r.0).ok_or_else(|| anyhow!("nothing is being recorded"))?;
    // SIGINT lets the recorder finalise the file; the watcher task then reports the result.
    util::signal(pid, libc::SIGINT);
    for _ in 0..40 {
        tokio::time::sleep(Duration::from_millis(100)).await;
        if d().capture.recording.lock().unwrap().is_none() {
            return Ok(());
        }
    }
    util::signal(pid, libc::SIGKILL);
    Ok(())
}

/// Finalise a running recording when the daemon exits.
pub async fn shutdown() {
    if d().capture.recording.lock().unwrap().is_some() {
        let _ = stop_recording().await;
    }
}

pub async fn run() -> Result<()> {
    publish();
    Ok(())
}

pub async fn call(name: &str, p: &Value) -> Result<Value> {
    match name {
        "start" => start(p.str_or("mode", "region"), p.get("monitor").and_then(Value::as_str)).await?,
        "shot" => shot(p).await?,
        "record" => record(p).await?,
        "stop" => stop_recording().await?,
        "cancel" => {
            let _ = std::fs::remove_file(freeze_file());
        }
        _ => bail!("unknown method capture.{name}"),
    }
    Ok(Value::Null)
}
