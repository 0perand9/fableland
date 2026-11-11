//! Film and series catalogue (Cinemeta, the public Stremio metadata service).
//!
//! Request/response only: trending lists, search, details. Picking a title opens
//! the link template from the settings (`movies.openWith`) in the browser.
//! Other plugins can add to a title's page through the `movies.details.actions`
//! slot (see the arr plugin).

use fable_plugin::util::{now_s, read_json, url_encode, write_json};
use fable_plugin::*;

const API: &str = "https://v3-cinemeta.strem.io";
const TRENDING_MAX_AGE: u64 = 12 * 3600;

pub fn plugin() -> Plugin {
    Plugin::new().call(|ctx, method, p| async move { call(&ctx, &method, &p).await })
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

struct History(std::path::PathBuf);

impl History {
    fn of(ctx: &Ctx) -> Self {
        History(ctx.state_dir().join("history.json"))
    }

    fn read(&self) -> Value {
        read_json(&self.0).filter(Value::is_object).unwrap_or_else(|| json!({ "searches": [], "watched": [] }))
    }

    /// Put `entry` at the front of a list, without duplicates, capped at `max`.
    fn remember(&self, list: &str, entry: Value, same: impl Fn(&Value) -> bool, max: usize) -> Result<Value> {
        let mut h = self.read();
        let mut items: Vec<Value> = h[list].as_array().cloned().unwrap_or_default();
        items.retain(|i| !same(i));
        items.insert(0, entry);
        items.truncate(max);
        h[list] = json!(items);
        write_json(&self.0, &h)?;
        Ok(h)
    }
}

async fn call(ctx: &Ctx, method: &str, p: &Value) -> Result<Value> {
    let kind = kind(p);
    let history = History::of(ctx);
    match method {
        "trending" => {
            let cache_file = ctx.cache_dir().join("trending.json");
            let mut cache = read_json(&cache_file).filter(Value::is_object).unwrap_or_else(|| json!({}));
            let fresh = now_s().saturating_sub(cache[kind]["at"].as_u64().unwrap_or(0)) < TRENDING_MAX_AGE;
            if !fresh || cache[kind]["items"].as_array().is_none_or(|a| a.is_empty()) {
                let list = titles(&http::get(format!("{API}/catalog/{kind}/top.json")).json().await?, kind);
                cache[kind] = json!({ "at": now_s(), "items": list });
                let _ = write_json(&cache_file, &cache);
            }
            Ok(cache[kind]["items"].clone())
        }
        "search" => {
            let query = p.str("query")?.trim();
            if query.is_empty() {
                bail!("nothing to search for");
            }
            let found = titles(&http::get(format!("{API}/catalog/{kind}/top/search={}.json", url_encode(query))).json().await?, kind);
            Ok(json!(found))
        }
        "details" => {
            let id = p.str("id")?;
            let reply = http::get(format!("{API}/meta/{kind}/{id}.json")).json().await?;
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
        "history" => Ok(history.read()),
        // Search-as-you-type sends many queries; the UI says which ones the user settled on.
        "rememberSearch" => {
            let query = p.str("query")?.trim();
            if query.is_empty() {
                return Ok(history.read());
            }
            let key = query.to_lowercase();
            history.remember("searches", json!(query), |i| i.as_str().is_some_and(|s| s.to_lowercase() == key), 10)
        }
        "forgetSearch" => {
            let query = p.str("query")?;
            let mut h = history.read();
            let kept: Vec<Value> = h["searches"].as_array().cloned().unwrap_or_default().into_iter().filter(|s| s.as_str() != Some(query)).collect();
            h["searches"] = json!(kept);
            write_json(&history.0, &h)?;
            Ok(h)
        }
        "open" => {
            let (id, title) = (p.str("id")?, p.str_or("title", ""));
            let template = ctx.setting_str("openWith");
            if template.is_empty() {
                bail!("set a link template for opening titles in Settings");
            }
            let mut url = template.replace("{id}", id).replace("{title}", &url_encode(title)).replace("{type}", kind);
            for key in ["season", "episode"] {
                url = url.replace(&format!("{{{key}}}"), &p.num_or(key, 1.0).to_string());
            }
            ctx.open(&url);
            history.remember("watched", json!({ "id": id, "title": title, "poster": p.str_or("poster", ""), "type": kind }), |i| i["id"].as_str() == Some(id), 15)
        }
        _ => bail!("unknown method movies.{method}"),
    }
}
