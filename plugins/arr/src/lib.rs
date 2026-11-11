//! Sonarr and Radarr: whether a title is in your library, and a request that
//! adds it there — a series to Sonarr, a film to Radarr — and starts a search.
//!
//! The button lives on a title's page in the movies plugin (the
//! `movies.details.actions` slot); this plugin does nothing without it but has
//! nothing to do with Cinemeta either: titles are known by their IMDb id.

use fable_plugin::util::{expand, url_encode};
use fable_plugin::*;

pub fn plugin() -> Plugin {
    Plugin::new()
        // `arr` says which of the two are set up, so the button only shows where it can work.
        .run(|ctx| async move {
            let mut changes = ctx.setting_changes();
            loop {
                ctx.publish(json!({ "sonarr": configured(&ctx, Service::Sonarr), "radarr": configured(&ctx, Service::Radarr) }));
                if changes.changed().await.is_err() {
                    return Ok(());
                }
            }
        })
        .call(|ctx, method, p| async move { call(&ctx, &method, &p).await })
}

#[derive(Clone, Copy, Debug, PartialEq)]
enum Service {
    Sonarr,
    Radarr,
}

impl Service {
    fn for_type(kind: &str) -> Self {
        if matches!(kind, "series" | "tv") {
            Service::Sonarr
        } else {
            Service::Radarr
        }
    }

    fn named(name: &str) -> Result<Self> {
        match name {
            "sonarr" => Ok(Service::Sonarr),
            "radarr" => Ok(Service::Radarr),
            other => bail!("unknown service '{other}' (sonarr or radarr)"),
        }
    }

    fn key(self) -> &'static str {
        match self {
            Service::Sonarr => "sonarr",
            Service::Radarr => "radarr",
        }
    }

    fn title(self) -> &'static str {
        match self {
            Service::Sonarr => "Sonarr",
            Service::Radarr => "Radarr",
        }
    }

    /// What it keeps: its API's word for it, which is also the path of its pages.
    fn noun(self) -> &'static str {
        match self {
            Service::Sonarr => "series",
            Service::Radarr => "movie",
        }
    }
}

/// The server has never heard of the title: an answer, not a failure.
#[derive(Debug)]
struct NotFound(Service);

impl std::fmt::Display for NotFound {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        write!(f, "{} does not know this title", self.0.title())
    }
}

impl std::error::Error for NotFound {}

fn configured(ctx: &Ctx, service: Service) -> bool {
    let set = |key: &str| !ctx.setting_str(&format!("{}.{key}", service.key())).trim().is_empty();
    set("url") && (set("apiKey") || set("apiKeyFile"))
}

/// One of the two servers, as the settings describe it.
struct Server {
    service: Service,
    url: String,
    key: String,
}

impl Server {
    fn of(ctx: &Ctx, service: Service) -> Result<Self> {
        let setting = |key: &str| ctx.setting_str(&format!("{}.{key}", service.key())).trim().to_string();
        if !configured(ctx, service) {
            bail!("{} is not set up: add its address and API key in Settings", service.title());
        }
        // A key in a file stays out of settings.json and out of the Nix store.
        let key = match setting("apiKeyFile") {
            file if !file.is_empty() => std::fs::read_to_string(expand(&file))
                .with_context(|| format!("cannot read the {} API key from {file}", service.title()))?
                .trim()
                .to_string(),
            _ => setting("apiKey"),
        };
        Ok(Server { service, url: setting("url").trim_end_matches('/').to_string(), key })
    }

    async fn get(&self, path: &str) -> Result<Value> {
        http::get(format!("{}/api/v3/{path}", self.url)).header("X-Api-Key", &self.key).json().await.with_context(|| self.service.title())
    }

    async fn post(&self, path: &str, body: Value) -> Result<Value> {
        http::post(format!("{}/api/v3/{path}", self.url), body).header("X-Api-Key", &self.key).json().await.with_context(|| self.service.title())
    }

    /// The server's own entry for a title: from the library when it is there, otherwise what it would add.
    async fn lookup(&self, imdb: &str, title: &str) -> Result<Value> {
        let found = match self.service {
            Service::Radarr => match self.get(&format!("movie/lookup/imdb?imdbId={imdb}")).await {
                Ok(reply) => Some(if reply.is_array() { reply[0].clone() } else { reply }).filter(|m| m.is_object()),
                Err(e) if http::is_status(&e, 404) => None,
                Err(e) => return Err(e),
            },
            // Sonarr finds series by IMDb id where it can, and by name otherwise.
            Service::Sonarr => {
                let same = |reply: Value| reply.as_array().and_then(|list| list.iter().find(|s| s["imdbId"].as_str() == Some(imdb)).cloned());
                let by_id = same(self.get(&format!("series/lookup?term={}", url_encode(&format!("imdb:{imdb}")))).await.unwrap_or(Value::Null));
                match by_id {
                    Some(series) => Some(series),
                    None if !title.is_empty() => same(self.get(&format!("series/lookup?term={}", url_encode(title))).await?),
                    None => None,
                }
            }
        };
        let item = found.ok_or(NotFound(self.service))?;
        // A series from the lookup says little about what is downloaded.
        match (self.service, item["id"].as_i64()) {
            (Service::Sonarr, Some(id)) if id > 0 => self.get(&format!("series/{id}")).await,
            _ => Ok(item),
        }
    }

    /// What the button shows.
    fn describe(&self, item: &Value) -> Value {
        let in_library = item["id"].as_i64().unwrap_or(0) > 0;
        let have = match self.service {
            Service::Radarr => json!(if item["hasFile"].as_bool() == Some(true) { 100 } else { 0 }),
            Service::Sonarr => item["statistics"]["percentOfEpisodes"].clone(),
        };
        let link = match item["titleSlug"].as_str() {
            Some(slug) if in_library => format!("{}/{}/{slug}", self.url, self.service.noun()),
            _ => String::new(),
        };
        json!({
            "service": self.service.key(), "name": self.service.title(), "found": true, "title": item["title"],
            "inLibrary": in_library, "monitored": item["monitored"], "have": have, "link": link,
        })
    }

    /// The quality profile to add with: the one named in the settings, or the first.
    async fn profile(&self, wanted: &str) -> Result<(i64, String)> {
        let profiles = self.get("qualityprofile").await?;
        let list = profiles.as_array().map(Vec::as_slice).unwrap_or_default();
        let pick = list.iter().find(|p| p["name"].as_str().is_some_and(|n| n.eq_ignore_ascii_case(wanted.trim()))).or(list.first());
        match pick {
            Some(p) => Ok((p["id"].as_i64().unwrap_or(0), p["name"].as_str().unwrap_or("").to_string())),
            None => bail!("{} has no quality profiles", self.service.title()),
        }
    }

    /// The root folder to add to: the one in the settings, or the first.
    async fn root_folder(&self, wanted: &str) -> Result<String> {
        let folders = self.get("rootfolder").await?;
        let paths: Vec<&str> = folders.as_array().map(Vec::as_slice).unwrap_or_default().iter().filter_map(|f| f["path"].as_str()).collect();
        let wanted = wanted.trim().trim_end_matches('/');
        let pick = paths.iter().find(|p| !wanted.is_empty() && p.trim_end_matches('/') == wanted).or(paths.first());
        match pick {
            Some(path) => Ok(path.to_string()),
            None => bail!("{} has no root folder to add to", self.service.title()),
        }
    }
}

async fn call(ctx: &Ctx, method: &str, p: &Value) -> Result<Value> {
    let service = match p.get("service").and_then(Value::as_str) {
        Some(name) => Service::named(name)?,
        None => Service::for_type(p.str_or("type", "movie")),
    };
    let setting = |key: &str| ctx.setting_str(&format!("{}.{key}", service.key()));
    match method {
        // {id, title?, type} → what the server knows of the title ("found": false when nothing).
        "lookup" => {
            let server = Server::of(ctx, service)?;
            match server.lookup(p.str("id")?, p.str_or("title", "")).await {
                Ok(item) => Ok(server.describe(&item)),
                Err(e) if e.downcast_ref::<NotFound>().is_some() => Ok(json!({ "service": service.key(), "name": service.title(), "found": false })),
                Err(e) => Err(e),
            }
        }
        // {id, title?, type} → the same, once the title has been added.
        "request" => {
            let server = Server::of(ctx, service)?;
            let item = server.lookup(p.str("id")?, p.str_or("title", "")).await?;
            if item["id"].as_i64().unwrap_or(0) > 0 {
                return Ok(server.describe(&item));
            }
            let (profile, _) = server.profile(&setting("qualityProfile")).await?;
            let root = server.root_folder(&setting("rootFolder")).await?;
            let search = ctx.setting("search") != false;
            let mut body = item;
            body["qualityProfileId"] = json!(profile);
            body["rootFolderPath"] = json!(root);
            body["monitored"] = json!(true);
            match service {
                Service::Sonarr => {
                    body["seasonFolder"] = json!(true);
                    body["addOptions"] = json!({ "monitor": "all", "searchForMissingEpisodes": search, "searchForCutoffUnmetEpisodes": false });
                    // Sonarr 3 wants a language profile; 4 has none and ignores it.
                    if let Some(id) = server.get("languageprofile").await.ok().and_then(|l| l[0]["id"].as_i64()) {
                        body["languageProfileId"] = json!(id);
                    }
                }
                Service::Radarr => {
                    body["minimumAvailability"] = json!("released");
                    body["addOptions"] = json!({ "searchForMovie": search });
                }
            }
            let added = server.post(service.noun(), body).await?;
            let name = added["title"].as_str().unwrap_or("The title");
            ctx.toast("success", service.title(), &format!("{name} was added{}", if search { " and is being searched for" } else { "" }));
            Ok(server.describe(&added))
        }
        // {service} → whether the server answers, and what a request would use.
        "test" => {
            let server = Server::of(ctx, service)?;
            let status = server.get("system/status").await?;
            let (_, profile) = server.profile(&setting("qualityProfile")).await?;
            let root = server.root_folder(&setting("rootFolder")).await?;
            Ok(json!({ "version": status["version"], "profile": profile, "rootFolder": root }))
        }
        _ => bail!("unknown method arr.{method}"),
    }
}
