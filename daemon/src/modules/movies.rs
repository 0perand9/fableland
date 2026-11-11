//! Film and series catalogue (Cinemeta, the public Stremio metadata service).
//!
//! Request/response only: trending lists, search, details. Picking a title opens
//! the URL template from settings (`movies.openWith`) in the browser.

use crate::util::Params;
use crate::{d, util};
use anyhow::{anyhow, bail, Result};
use serde_json::{json, Value};
use std::time::Duration;

const API: &str = "https://v3-cinemeta.strem.io";
const TRENDING_MAX_AGE: u64 = 12 * 3600;

fn state_file() -> std::path::PathBuf {
    util::dirs().state.join("movies.json")
}

fn cache_file() -> std::path::PathBuf {
    util::dirs().cache.join("movies-trending.json")
}

fn encode(s: &str) -> String {
    s.bytes().map(|b| if b.is_ascii_alphanumeric() || b"-_.~".contains(&b) { (b as char).to_string() } else { format!("%{b:02X}") }).collect()
}

async fn get(url: String) -> Result<Value> {
    tokio::task::spawn_blocking(move || -> Result<Value> { Ok(ureq::get(&url).timeout(Duration::from_secs(12)).call()?.into_json()?) }).await?
}

fn kind(p: &Value) -> &'static str {
    if matches!(p.str_or("type", "movie"), "tv" | "series") {
        "series"
    } else {
        "movie"
    }
}

fn titles(reply: &Value, kind: &str) -> Vec<Value> {
    reply["metas"]
        .as_array()
        .map(|a| a.as_slice())
        .unwrap_or_default()
        .iter()
        .filter(|m| m["id"].as_str().is_some_and(|id| id.starts_with("tt")))
        .map(|m| json!({ "id": m["id"], "title": m["name"], "poster": m["poster"], "year": m["releaseInfo"], "rating": m["imdbRating"], "type": kind }))
        .collect()
}

fn history() -> Value {
    util::read_json(&state_file()).filter(Value::is_object).unwrap_or_else(|| json!({ "searches": [], "watched": [] }))
}

/// Put `entry` at the front of a history list, without duplicates, capped at `max`.
fn remember(list: &str, entry: Value, same: impl Fn(&Value) -> bool, max: usize) -> Result<()> {
    let mut h = history();
    let mut items: Vec<Value> = h[list].as_array().cloned().unwrap_or_default();
    items.retain(|i| !same(i));
    items.insert(0, entry);
    items.truncate(max);
    h[list] = json!(items);
    util::write_json(&state_file(), &h)
}

pub async fn call(name: &str, p: &Value) -> Result<Value> {
    let kind = kind(p);
    match name {
        "trending" => {
            let mut cache = util::read_json(&cache_file()).filter(Value::is_object).unwrap_or_else(|| json!({}));
            let fresh = util::now_s().saturating_sub(cache[kind]["at"].as_u64().unwrap_or(0)) < TRENDING_MAX_AGE;
            if !fresh || cache[kind]["items"].as_array().is_none_or(|a| a.is_empty()) {
                let list = titles(&get(format!("{API}/catalog/{kind}/top.json")).await?, kind);
                cache[kind] = json!({ "at": util::now_s(), "items": list });
                let _ = util::write_json(&cache_file(), &cache);
            }
            Ok(cache[kind]["items"].clone())
        }
        "search" => {
            let query = p.str("query")?.trim().to_string();
            if query.is_empty() {
                bail!("nothing to search for");
            }
            let found = titles(&get(format!("{API}/catalog/{kind}/top/search={}.json", encode(&query))).await?, kind);
            Ok(json!(found))
        }
        "details" => {
            let id = p.str("id")?;
            let reply = get(format!("{API}/meta/{kind}/{id}.json")).await?;
            let m = &reply["meta"];
            let mut episodes: Vec<Value> = m["videos"]
                .as_array()
                .map(|a| a.as_slice())
                .unwrap_or_default()
                .iter()
                .filter(|v| v["season"].as_i64().unwrap_or(0) > 0)
                .map(|v| json!({ "season": v["season"], "episode": v["episode"].as_i64().or(v["number"].as_i64()), "title": v["name"].as_str().or(v["title"].as_str()).unwrap_or("") }))
                .collect();
            episodes.sort_by_key(|e| (e["season"].as_i64().unwrap_or(0), e["episode"].as_i64().unwrap_or(0)));
            Ok(json!({
                "id": id, "type": kind, "title": m["name"], "description": m["description"], "poster": m["poster"], "background": m["background"],
                "year": m["releaseInfo"], "rating": m["imdbRating"], "runtime": m["runtime"], "genres": m["genres"], "cast": m["cast"], "episodes": episodes,
            }))
        }
        "history" => Ok(history()),
        // Search-as-you-type sends many queries; the UI says which ones the user settled on.
        "rememberSearch" => {
            let query = p.str("query")?.trim().to_string();
            let key = query.to_lowercase();
            if !query.is_empty() {
                remember("searches", json!(query), |i| i.as_str().is_some_and(|s| s.to_lowercase() == key), 10)?;
            }
            Ok(history())
        }
        "forgetSearch" => {
            let query = p.str("query")?;
            let mut h = history();
            let kept: Vec<Value> = h["searches"].as_array().cloned().unwrap_or_default().into_iter().filter(|s| s.as_str() != Some(query)).collect();
            h["searches"] = json!(kept);
            util::write_json(&state_file(), &h)?;
            Ok(h)
        }
        "open" => {
            let (id, title) = (p.str("id")?, p.str_or("title", ""));
            let template = d().settings.str("movies.openWith");
            if template.is_empty() {
                return Err(anyhow!("set a link template for opening titles in Settings"));
            }
            let mut url = template.replace("{id}", id).replace("{title}", &encode(title)).replace("{type}", kind);
            for key in ["season", "episode"] {
                url = url.replace(&format!("{{{key}}}"), &p.num_or(key, 1.0).to_string());
            }
            util::spawn_detached("xdg-open", &[&url]);
            remember("watched", json!({ "id": id, "title": title, "poster": p.str_or("poster", ""), "type": kind }), |i| i["id"].as_str() == Some(id), 15)?;
            Ok(history())
        }
        _ => bail!("unknown method movies.{name}"),
    }
}
