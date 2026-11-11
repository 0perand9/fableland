//! Wallpapers and the colour theme derived from them.
//!
//! Topics: `wallpaper` (library + current), `theme` (palette), `wallsearch`
//! (online search results). Thumbnails are made in-process; `awww`/`swww` shows
//! still images, `mpvpaper` shows videos, `matugen` turns a wallpaper into a palette.

use crate::util::Params;
use crate::{d, features, log, util};
use anyhow::{anyhow, bail, Context, Result};
use serde_json::{json, Value};
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::{Arc, Mutex};
use std::time::Duration;
use tokio::sync::{Notify, Semaphore};

const IMAGE_EXT: [&str; 6] = ["jpg", "jpeg", "png", "webp", "gif", "bmp"];
const VIDEO_EXT: [&str; 4] = ["mp4", "mkv", "mov", "webm"];
const TRANSITIONS: [&str; 10] = ["fade", "left", "right", "top", "bottom", "wipe", "grow", "center", "outer", "wave"];
const USER_AGENT: &str = "Mozilla/5.0 (X11; Linux x86_64; rv:140.0) Gecko/20100101 Firefox/140.0";

#[derive(Default)]
pub struct Wallpaper {
    items: Mutex<Vec<Value>>,
    current: Mutex<Value>,
    palette: Mutex<Value>,
    busy: AtomicBool,
    rescan: Notify,
    /// Bumped to cancel a running online search.
    search_generation: AtomicU64,
    search: Mutex<Value>,
}

fn ext_of(path: &Path) -> String {
    path.extension().and_then(|e| e.to_str()).unwrap_or("").to_lowercase()
}

fn is_video(path: &Path) -> bool {
    VIDEO_EXT.contains(&ext_of(path).as_str())
}

fn wallpaper_dir() -> PathBuf {
    util::expand(&d().settings.str("wallpaper.dir"))
}

fn thumbs_dir() -> PathBuf {
    let dir = util::dirs().cache.join("thumbs");
    util::ensure_dir(&dir);
    dir
}

fn state_file() -> PathBuf {
    util::dirs().state.join("wallpaper.json")
}

fn theme_file() -> PathBuf {
    util::dirs().state.join("theme.json")
}

// ---------------------------------------------------------------- library

/// Saturation-weighted average colour, so one vivid subject outweighs a grey sky.
fn dominant_color(img: &image::RgbImage) -> String {
    let (mut sum, mut total) = ([0.0f64; 3], 0.0f64);
    for px in img.pixels().step_by(7) {
        let [r, g, b] = px.0;
        let (max, min) = (r.max(g).max(b) as f64, r.min(g).min(b) as f64);
        let weight = 0.15 + if max > 0.0 { (max - min) / max } else { 0.0 };
        for (s, c) in sum.iter_mut().zip([r, g, b]) {
            *s += c as f64 * weight;
        }
        total += weight;
    }
    let total = total.max(1e-9);
    format!("#{:02x}{:02x}{:02x}", (sum[0] / total) as u8, (sum[1] / total) as u8, (sum[2] / total) as u8)
}

/// Colour family used by the picker's filter chips.
fn bucket(hex: &str) -> &'static str {
    let n = u32::from_str_radix(hex.trim_start_matches('#'), 16).unwrap_or(0);
    let (r, g, b) = (((n >> 16) & 255) as f64 / 255.0, ((n >> 8) & 255) as f64 / 255.0, (n & 255) as f64 / 255.0);
    let (max, min) = (r.max(g).max(b), r.min(g).min(b));
    let delta = max - min;
    if max < 0.08 || (max > 0.0 && delta / max < 0.12) {
        return "mono";
    }
    let hue = 60.0 * if max == r { ((g - b) / delta).rem_euclid(6.0) } else if max == g { (b - r) / delta + 2.0 } else { (r - g) / delta + 4.0 };
    match hue as u32 {
        0..=14 | 345..=360 => "red",
        15..=44 => "orange",
        45..=74 => "yellow",
        75..=164 => "green",
        165..=259 => "blue",
        260..=314 => "purple",
        _ => "pink",
    }
}

/// Make the thumbnail for one file and return its dominant colour.
fn make_thumb(src: &Path, thumb: &Path) -> Result<String> {
    let scratch = thumb.with_extension("part.jpg");
    if is_video(src) {
        // A frame a few seconds in is usually more representative than the first one.
        let status = std::process::Command::new("ffmpeg")
            .args(["-y", "-loglevel", "error", "-ss", "3", "-i"])
            .arg(src)
            .args(["-frames:v", "1", "-vf", "scale=-2:420", "-q:v", "4"])
            .arg(&scratch)
            .stdin(std::process::Stdio::null())
            .status()
            .context("ffmpeg is needed for video wallpaper thumbnails")?;
        if !status.success() || !scratch.exists() {
            bail!("ffmpeg could not read {}", src.display());
        }
    } else {
        let img = image::open(src).with_context(|| format!("cannot read {}", src.display()))?;
        img.thumbnail(1400, 420).to_rgb8().save_with_format(&scratch, image::ImageFormat::Jpeg)?;
    }
    let color = dominant_color(&image::open(&scratch)?.thumbnail(96, 96).to_rgb8());
    std::fs::rename(&scratch, thumb)?;
    Ok(color)
}

fn publish() {
    let w = &d().wallpaper;
    d().hub.publish(
        "wallpaper",
        &json!({
            "dir": wallpaper_dir().to_string_lossy(),
            "busy": w.busy.load(Ordering::Relaxed),
            "current": *w.current.lock().unwrap(),
            "items": *w.items.lock().unwrap(),
            "tools": { "images": image_tool().is_some(), "videos": util::which("mpvpaper"), "theme": features::on("palette") && util::which("matugen") },
        }),
    );
}

async fn scan() -> Result<()> {
    let w = &d().wallpaper;
    let dir = wallpaper_dir();
    let thumbs = thumbs_dir();
    let index_file = util::dirs().cache.join("wallpapers.json");
    let mut index = util::read_json(&index_file).filter(Value::is_object).unwrap_or_else(|| json!({}));

    let mut files: Vec<PathBuf> = std::fs::read_dir(&dir)
        .map(|rd| rd.flatten().map(|e| e.path()).filter(|p| p.is_file() && (IMAGE_EXT.contains(&ext_of(p).as_str()) || is_video(p))).collect())
        .unwrap_or_default();
    files.sort_by_key(|p| p.file_name().map(|n| n.to_string_lossy().to_lowercase()).unwrap_or_default());

    // The thumbnail name encodes path, size and mtime: editing a file invalidates its thumbnail.
    let entries: Vec<(PathBuf, String)> = files
        .into_iter()
        .map(|p| {
            let meta = std::fs::metadata(&p).ok();
            let key = util::hash_str(&format!("{}|{}|{}", p.display(), meta.as_ref().map(|m| m.len()).unwrap_or(0), util::mtime_s(&p)));
            (p, key)
        })
        .collect();

    let item = |path: &Path, key: &str, color: &str| {
        json!({
            "name": path.file_name().map(|n| n.to_string_lossy()).unwrap_or_default(),
            "path": path.to_string_lossy(), "thumb": thumbs.join(format!("{key}.jpg")).to_string_lossy(),
            "video": is_video(path), "color": color, "bucket": bucket(color),
        })
    };

    let mut ready = Vec::new();
    let mut missing = Vec::new();
    for (path, key) in &entries {
        match index[key]["color"].as_str() {
            Some(color) if thumbs.join(format!("{key}.jpg")).exists() => ready.push(item(path, key, color)),
            _ => missing.push((path.clone(), key.clone())),
        }
    }
    *w.items.lock().unwrap() = ready;
    w.busy.store(!missing.is_empty(), Ordering::Relaxed);
    publish();
    if missing.is_empty() {
        prune(&entries, &thumbs, &mut index, &index_file);
        return Ok(());
    }

    log!("generating {} wallpaper thumbnails", missing.len());
    let workers = Arc::new(Semaphore::new(std::thread::available_parallelism().map(|n| n.get() / 2).unwrap_or(2).clamp(1, 8)));
    let (tx, mut rx) = tokio::sync::mpsc::unbounded_channel();
    for (path, key) in missing {
        let (workers, tx, thumb) = (workers.clone(), tx.clone(), thumbs.join(format!("{key}.jpg")));
        tokio::spawn(async move {
            let _permit = workers.acquire().await;
            let (p, t) = (path.clone(), thumb);
            let result = tokio::task::spawn_blocking(move || make_thumb(&p, &t)).await;
            let _ = tx.send((path, key, result.ok().and_then(Result::ok)));
        });
    }
    drop(tx);
    let mut last_publish = std::time::Instant::now();
    while let Some((path, key, color)) = rx.recv().await {
        let Some(color) = color else {
            log!("skipping unreadable wallpaper {}", path.display());
            continue;
        };
        index[&key] = json!({ "color": color });
        w.items.lock().unwrap().push(item(&path, &key, &color));
        // Let the picker fill in progressively without flooding it.
        if last_publish.elapsed() > Duration::from_millis(400) {
            sort_items();
            publish();
            last_publish = std::time::Instant::now();
        }
    }
    sort_items();
    w.busy.store(false, Ordering::Relaxed);
    publish();
    prune(&entries, &thumbs, &mut index, &index_file);
    Ok(())
}

fn sort_items() {
    d().wallpaper.items.lock().unwrap().sort_by_key(|i| i["name"].as_str().unwrap_or("").to_lowercase());
}

/// Forget thumbnails whose source file is gone.
fn prune(entries: &[(PathBuf, String)], thumbs: &Path, index: &mut Value, index_file: &Path) {
    let live: std::collections::HashSet<&str> = entries.iter().map(|(_, k)| k.as_str()).collect();
    if let Some(map) = index.as_object_mut() {
        map.retain(|k, _| live.contains(k.as_str()));
    }
    if let Ok(rd) = std::fs::read_dir(thumbs) {
        for e in rd.flatten() {
            let stem = e.path().file_stem().map(|s| s.to_string_lossy().into_owned()).unwrap_or_default();
            if !live.contains(stem.as_str()) {
                let _ = std::fs::remove_file(e.path());
            }
        }
    }
    let _ = util::write_json(index_file, index);
}

// ---------------------------------------------------------------- applying

fn image_tool() -> Option<&'static str> {
    util::first_installed(&["awww", "swww"])
}

async fn ensure_image_daemon(tool: &str) -> bool {
    if util::run(tool, &["query"]).await.is_ok() {
        return true;
    }
    util::spawn_detached(&format!("{tool}-daemon"), &[]);
    for _ in 0..30 {
        tokio::time::sleep(Duration::from_millis(100)).await;
        if util::run(tool, &["query"]).await.is_ok() {
            return true;
        }
    }
    false
}

/// The image the wallpaper daemon is currently showing, if any.
async fn displayed_image() -> Option<String> {
    let out = util::run(image_tool()?, &["query"]).await.ok()?;
    let path = out.lines().find_map(|l| l.split_once("image: ").map(|(_, p)| p.trim().to_string()))?;
    Path::new(&path).is_file().then_some(path)
}

fn thumb_of(path: &str) -> Option<String> {
    d().wallpaper.items.lock().unwrap().iter().find(|i| i["path"].as_str() == Some(path)).and_then(|i| i["thumb"].as_str().map(String::from))
}

async fn show(path: &Path, outputs: &[String], animate: bool) -> Result<()> {
    let path_str = path.to_string_lossy().into_owned();
    let had_video = !util::pids_of("mpvpaper").is_empty();
    if is_video(path) {
        if !util::which("mpvpaper") {
            bail!("mpvpaper is needed for video wallpapers");
        }
        for pid in util::pids_of("mpvpaper") {
            util::signal(pid, libc::SIGTERM);
        }
        let options = "loop --no-audio --hwdec=auto --profile=high-quality --video-sync=display-resample --interpolation --tscale=oversample";
        let targets: Vec<String> = if outputs.is_empty() { vec!["*".into()] } else { outputs.to_vec() };
        for output in targets {
            util::spawn_detached("mpvpaper", &["-o", options, &output, &path_str]);
        }
        return Ok(());
    }
    let tool = image_tool().ok_or_else(|| anyhow!("awww (or swww) is needed to set wallpapers"))?;
    if !ensure_image_daemon(tool).await {
        bail!("could not start {tool}-daemon");
    }
    let transition = match d().settings.str("wallpaper.transition").as_str() {
        _ if !animate => "none".to_string(),
        "" | "random" => TRANSITIONS[(util::now_ms() % TRANSITIONS.len() as u64) as usize].to_string(),
        chosen => chosen.to_string(),
    };
    let joined = outputs.join(",");
    let mut args = vec!["img"];
    if !outputs.is_empty() {
        args.extend(["-o", &joined]);
    }
    args.extend([path_str.as_str(), "--transition-type", &transition, "--transition-pos", "0.5,0.5", "--transition-fps", "144", "--transition-duration", "0.4"]);
    util::run(tool, &args).await?;
    if had_video {
        // The still is now in place underneath; removing the video reveals it.
        for pid in util::pids_of("mpvpaper") {
            util::signal(pid, libc::SIGTERM);
        }
    }
    Ok(())
}

async fn apply(path: &Path, outputs: Vec<String>) -> Result<()> {
    if !path.is_file() {
        bail!("{} does not exist", path.display());
    }
    show(path, &outputs, true).await?;
    let path_str = path.to_string_lossy().into_owned();
    // A still frame stands in for a video wherever an image is needed (lock screen, theme).
    let image = if is_video(path) { thumb_of(&path_str).unwrap_or_default() } else { path_str.clone() };
    let current = json!({ "path": path_str, "image": image, "video": is_video(path), "outputs": outputs });
    *d().wallpaper.current.lock().unwrap() = current.clone();
    let _ = util::write_json(&state_file(), &current);
    publish();
    let source = thumb_of(&path_str).unwrap_or(image);
    tokio::spawn(async move {
        if let Err(e) = generate_theme(&source).await {
            log!("theme generation: {e:#}");
        }
    });
    Ok(())
}

/// Show the current wallpaper again (after a monitor change).
pub async fn reapply() {
    let current = d().wallpaper.current.lock().unwrap().clone();
    if let Some(path) = current["path"].as_str() {
        let _ = show(Path::new(path), &[], false).await;
    }
}

// ---------------------------------------------------------------- theme

/// Catppuccin Mocha, used until a wallpaper palette exists, when matugen is
/// missing and when the `palette` feature is off.
fn default_palette() -> Value {
    json!({
        "generated": false,
        "base": "#1e1e2e", "mantle": "#181825", "crust": "#11111b",
        "surface0": "#313244", "surface1": "#45475a", "surface2": "#585b70",
        "text": "#cdd6f4", "subtext": "#a6adc8", "dim": "#7f849c", "faint": "#45475a",
        "primary": "#cba6f7", "onPrimary": "#11111b", "secondary": "#89b4fa", "tertiary": "#f5c2e7", "error": "#f38ba8",
    })
}

/// Publish the palette to start with: the last one generated, if palettes are generated at all.
pub fn load_palette() {
    let saved = if features::on("palette") { util::read_json(&theme_file()) } else { None };
    let palette = saved.unwrap_or_else(default_palette);
    *d().wallpaper.palette.lock().unwrap() = palette.clone();
    d().hub.publish("theme", &palette);
}

async fn generate_theme(image: &str) -> Result<()> {
    if image.is_empty() || !features::on("palette") || !util::which("matugen") {
        return Ok(());
    }
    let s = &d().settings;
    let (scheme, mode) = (s.str("wallpaper.scheme"), s.str("wallpaper.mode"));
    // Besides printing the palette this renders the user's own matugen templates (terminal, editor, ...).
    let read_only = crate::options().read_only;
    let mut args = vec!["image", image, "-t", if scheme.is_empty() { "scheme-vibrant" } else { &scheme }, "-m", if mode == "light" { "light" } else { "dark" }, "--source-color-index", "0", "--json", "hex"];
    if read_only {
        args.push("--dry-run");
    }
    let out = util::run("matugen", &args).await?;
    let start = out.find('{').ok_or_else(|| anyhow!("matugen printed no palette"))?;
    let parsed: Value = serde_json::from_str(&out[start..])?;
    let role = |name: &str| parsed["colors"][name]["default"]["color"].as_str().unwrap_or("#000000").to_string();
    let palette = json!({
        "generated": true, "mode": mode, "scheme": scheme, "source": image,
        "base": role("surface_container_lowest"), "mantle": role("surface_container_low"), "crust": role("surface"),
        "surface0": role("surface_container"), "surface1": role("surface_container_high"), "surface2": role("surface_container_highest"),
        "text": role("on_surface"), "subtext": role("on_surface_variant"), "dim": role("outline"), "faint": role("outline_variant"),
        "primary": role("primary"), "onPrimary": role("on_primary"), "secondary": role("secondary"), "tertiary": role("tertiary"), "error": role("error"),
    });
    *d().wallpaper.palette.lock().unwrap() = palette.clone();
    let _ = util::write_json(&theme_file(), &palette);
    d().hub.publish("theme", &palette);
    apply_border_colors().await;
    if read_only {
        return Ok(());
    }

    // Terminals reload their colours on SIGUSR1; anything else goes through the user's hook.
    for name in ["kitty", ".kitty-wrapped"] {
        for pid in util::pids_of(name) {
            util::signal(pid, libc::SIGUSR1);
        }
    }
    let hook = s.str("wallpaper.themeHook");
    if !hook.is_empty() {
        util::spawn_detached("sh", &["-c", &hook]);
    }
    Ok(())
}

/// Window borders follow the palette. Re-run after a Hyprland config reload.
pub async fn apply_border_colors() {
    let p = d().wallpaper.palette.lock().unwrap().clone();
    if p["generated"] == true {
        super::hypr::set_border(p["primary"].as_str().unwrap_or(""), p["tertiary"].as_str().unwrap_or(""), p["surface0"].as_str().unwrap_or("")).await;
    }
}

// ---------------------------------------------------------------- online search

fn url_encode(s: &str) -> String {
    s.bytes().map(|b| if b.is_ascii_alphanumeric() || b"-_.~".contains(&b) { (b as char).to_string() } else { format!("%{b:02X}") }).collect()
}

fn http_get(url: &str) -> Result<ureq::Response> {
    Ok(ureq::get(url).set("User-Agent", USER_AGENT).set("Referer", "https://duckduckgo.com/").timeout(Duration::from_secs(12)).call()?)
}

fn download(url: &str, limit: u64) -> Result<Vec<u8>> {
    use std::io::Read;
    let mut data = Vec::new();
    http_get(url)?.into_reader().take(limit).read_to_end(&mut data)?;
    Ok(data)
}

fn search_dir() -> PathBuf {
    let dir = util::dirs().cache.join("search");
    util::ensure_dir(&dir);
    dir
}

fn publish_search(state: &str, query: &str, results: &[Value]) {
    let v = json!({ "state": state, "query": query, "results": results });
    *d().wallpaper.search.lock().unwrap() = v.clone();
    d().hub.publish("wallsearch", &v);
}

/// Image search through DuckDuckGo: fetch the session token, then page through results,
/// keeping only images that are at least Full HD.
async fn search(query: String) {
    let w = &d().wallpaper;
    let generation = w.search_generation.fetch_add(1, Ordering::SeqCst) + 1;
    let cancelled = move || d().wallpaper.search_generation.load(Ordering::SeqCst) != generation;
    let _ = std::fs::remove_dir_all(search_dir());
    let mut results: Vec<Value> = Vec::new();
    publish_search("running", &query, &results);

    let q = url_encode(&format!("{query} wallpaper"));
    let token = {
        let url = format!("https://duckduckgo.com/?q={q}&iax=images&ia=images");
        tokio::task::spawn_blocking(move || -> Result<String> {
            let page = http_get(&url)?.into_string()?;
            let at = page.find("vqd=").ok_or_else(|| anyhow!("search token not found"))? + 4;
            Ok(page[at..].trim_start_matches(['"', '\'']).chars().take_while(|c| c.is_ascii_digit() || *c == '-').collect())
        })
        .await
    };
    let Ok(Ok(token)) = token else {
        publish_search("error", &query, &results);
        return;
    };

    let mut next = format!("i.js?l=us-en&o=json&q={q}&vqd={token}&f=,,,&p=-1");
    for _page in 0..5 {
        if cancelled() {
            return;
        }
        let url = format!("https://duckduckgo.com/{next}");
        let Ok(Ok(page)) = tokio::task::spawn_blocking(move || -> Result<Value> { Ok(http_get(&url)?.into_json()?) }).await else { break };
        for r in page["results"].as_array().cloned().unwrap_or_default() {
            if cancelled() {
                return;
            }
            let (width, height) = (r["width"].as_u64().unwrap_or(0), r["height"].as_u64().unwrap_or(0));
            let (Some(full), Some(thumb_url)) = (r["image"].as_str(), r["thumbnail"].as_str()) else { continue };
            if width < 1920 || height < 1080 {
                continue;
            }
            let id = util::hash_str(full);
            let thumb = search_dir().join(format!("{id}.jpg"));
            let (t, target) = (thumb_url.to_string(), thumb.clone());
            let fetched = tokio::task::spawn_blocking(move || -> Result<()> { util::write_atomic(&target, &download(&t, 4 << 20)?) }).await;
            if !matches!(fetched, Ok(Ok(()))) {
                continue;
            }
            results.push(json!({ "id": id, "thumb": thumb.to_string_lossy(), "url": full, "width": width, "height": height, "title": r["title"] }));
            publish_search("running", &query, &results);
            if results.len() >= 60 {
                break;
            }
        }
        match page["next"].as_str() {
            Some(n) if results.len() < 60 => next = n.trim_start_matches('/').to_string(),
            _ => break,
        }
    }
    if !cancelled() {
        publish_search("done", &query, &results);
    }
}

/// Save a search result into the wallpaper folder and return its path.
async fn save_result(id: &str) -> Result<PathBuf> {
    let found = d().wallpaper.search.lock().unwrap()["results"].as_array().and_then(|a| a.iter().find(|r| r["id"].as_str() == Some(id)).cloned());
    let result = found.ok_or_else(|| anyhow!("that search result is gone"))?;
    let url = result["url"].as_str().unwrap_or("").to_string();
    let dir = wallpaper_dir();
    std::fs::create_dir_all(&dir)?;
    let target = dir.join(format!("online-{id}.jpg"));
    if target.exists() {
        return Ok(target);
    }
    let t = target.clone();
    tokio::task::spawn_blocking(move || -> Result<()> {
        let data = download(&url, 60 << 20)?;
        // Re-encode so the library only ever holds formats every tool can show.
        let img = image::load_from_memory(&data).context("the downloaded file is not an image")?;
        img.to_rgb8().save_with_format(&t, image::ImageFormat::Jpeg)?;
        Ok(())
    })
    .await??;
    Ok(target)
}

// ---------------------------------------------------------------- module

pub async fn run() -> Result<()> {
    let w = &d().wallpaper;
    // Empty until a wallpaper is known: the shell reads `current.image` without asking first.
    let mut current = util::read_json(&state_file()).unwrap_or_else(|| json!({}));
    if current["path"].is_null() {
        // First start: adopt whatever wallpaper is already on screen.
        if let Some(path) = displayed_image().await {
            current = json!({ "path": path, "image": path, "video": false, "outputs": [] });
        }
    }
    *w.current.lock().unwrap() = current;
    publish_search("idle", "", &[]);
    publish();

    // Bring the wallpaper back if nothing is showing one yet (fresh session).
    tokio::spawn(async {
        let current = d().wallpaper.current.lock().unwrap().clone();
        let Some(path) = current["path"].as_str().map(PathBuf::from) else { return };
        let showing = match image_tool() {
            Some(tool) => util::run(tool, &["query"]).await.is_ok() || !util::pids_of("mpvpaper").is_empty(),
            None => true,
        };
        if !showing && path.exists() {
            if let Err(e) = show(&path, &[], false).await {
                log!("restoring wallpaper: {e:#}");
            }
        }
        if d().wallpaper.palette.lock().unwrap()["generated"] != true {
            let _ = generate_theme(current["image"].as_str().unwrap_or("")).await;
        }
        apply_border_colors().await;
    });

    // Rescan when asked to, and when the wallpaper folder or theme settings change.
    tokio::spawn(async {
        let s = &d().settings;
        let mut rx = s.changes();
        let mut seen = (s.str("wallpaper.dir"), s.str("wallpaper.scheme"), s.str("wallpaper.mode"));
        while rx.changed().await.is_ok() {
            let now = (s.str("wallpaper.dir"), s.str("wallpaper.scheme"), s.str("wallpaper.mode"));
            if now.0 != seen.0 {
                d().wallpaper.rescan.notify_one();
            }
            if now.1 != seen.1 || now.2 != seen.2 {
                let image = d().wallpaper.current.lock().unwrap()["image"].as_str().unwrap_or("").to_string();
                if let Err(e) = generate_theme(&image).await {
                    d().hub.toast("error", "Theme", &format!("{e:#}"));
                }
            }
            seen = now;
        }
    });
    loop {
        if let Err(e) = scan().await {
            log!("wallpaper scan: {e:#}");
        }
        w.rescan.notified().await;
    }
}

pub async fn call(name: &str, p: &Value) -> Result<Value> {
    let w = &d().wallpaper;
    let outputs = || -> Vec<String> { p["outputs"].as_array().map(|a| a.iter().filter_map(|v| v.as_str().map(String::from)).collect()).unwrap_or_default() };
    match name {
        "apply" => apply(&util::expand(p.str("path")?), outputs()).await?,
        "cycle" => {
            let items = w.items.lock().unwrap().clone();
            if items.is_empty() {
                bail!("the wallpaper folder is empty");
            }
            let current = w.current.lock().unwrap()["path"].as_str().unwrap_or("").to_string();
            let at = items.iter().position(|i| i["path"].as_str() == Some(&current));
            let n = items.len();
            let next = match (p.str_or("direction", "next"), at) {
                ("random", _) => (util::now_ms() as usize / 7) % n,
                ("prev", Some(i)) => (i + n - 1) % n,
                (_, Some(i)) => (i + 1) % n,
                _ => 0,
            };
            apply(Path::new(items[next]["path"].as_str().unwrap_or("")), Vec::new()).await?;
        }
        "rescan" => w.rescan.notify_one(),
        "search" => {
            let query = p.str("query")?.trim().to_string();
            if query.is_empty() {
                bail!("type something to search for");
            }
            tokio::spawn(search(query));
        }
        "searchStop" => {
            w.search_generation.fetch_add(1, Ordering::SeqCst);
            let s = w.search.lock().unwrap().clone();
            publish_search("done", s["query"].as_str().unwrap_or(""), s["results"].as_array().map(|a| a.as_slice()).unwrap_or_default());
        }
        "saveResult" => {
            let path = save_result(p.str("id")?).await?;
            w.rescan.notify_one();
            if p.flag_or("apply", true) {
                apply(&path, outputs()).await?;
            }
            return Ok(json!(path.to_string_lossy()));
        }
        "regenerateTheme" => {
            let image = w.current.lock().unwrap()["image"].as_str().unwrap_or("").to_string();
            generate_theme(&image).await?;
        }
        _ => bail!("unknown method wallpaper.{name}"),
    }
    Ok(Value::Null)
}
