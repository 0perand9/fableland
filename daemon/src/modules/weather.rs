//! Weather (`weather` topic) from Open-Meteo (no account needed) or OpenWeatherMap.
//!
//! Both providers are reduced to the same list of time slots, and one function
//! turns slots into the days the UI shows. Days are split at local midnight.
//! Conditions are semantic names ("rain", "clear-night"); the UI picks icons.

use crate::util::Params;
use crate::{d, log, util};
use anyhow::{anyhow, bail, Result};
use chrono::{Local, TimeZone, Timelike};
use serde_json::{json, Value};
use std::time::Duration;
use tokio::sync::Notify;

#[derive(Default)]
pub struct Weather {
    refresh: Notify,
}

/// One point in time, provider-independent.
struct Slot {
    at: i64,
    temp: f64,
    feels: f64,
    humidity: f64,
    wind: f64,
    /// Chance of precipitation, percent.
    pop: f64,
    condition: &'static str,
    desc: String,
}

fn cache_file() -> std::path::PathBuf {
    util::dirs().cache.join("weather.json")
}

fn get(url: String) -> Result<Value> {
    Ok(ureq::get(&url).timeout(Duration::from_secs(12)).call()?.into_json()?)
}

fn title_case(s: &str) -> String {
    s.split_whitespace().map(|w| { let mut c = w.chars(); c.next().map(|f| f.to_uppercase().collect::<String>() + c.as_str()).unwrap_or_default() }).collect::<Vec<_>>().join(" ")
}

fn owm_condition(icon: &str) -> &'static str {
    let night = icon.ends_with('n');
    match &icon[..icon.len().min(2)] {
        "01" => if night { "clear-night" } else { "clear-day" },
        "02" => if night { "partly-night" } else { "partly-day" },
        "03" | "04" => "cloudy",
        "09" | "10" => "rain",
        "11" => "storm",
        "13" => "snow",
        "50" => "fog",
        _ => "cloudy",
    }
}

/// WMO weather interpretation code → (condition, description).
fn wmo(code: i64, day: bool) -> (&'static str, &'static str) {
    match code {
        0 => (if day { "clear-day" } else { "clear-night" }, "Clear Sky"),
        1 => (if day { "partly-day" } else { "partly-night" }, "Mainly Clear"),
        2 => (if day { "partly-day" } else { "partly-night" }, "Partly Cloudy"),
        3 => ("cloudy", "Overcast"),
        45 | 48 => ("fog", "Fog"),
        51..=57 => ("rain", "Drizzle"),
        61 | 80 => ("rain", "Light Rain"),
        63 | 81 => ("rain", "Rain"),
        65 | 82 => ("rain", "Heavy Rain"),
        66 | 67 => ("rain", "Freezing Rain"),
        71 | 85 => ("snow", "Light Snow"),
        73 | 77 => ("snow", "Snow"),
        75 | 86 => ("snow", "Heavy Snow"),
        95 => ("storm", "Thunderstorm"),
        96 | 99 => ("storm", "Thunderstorm With Hail"),
        _ => ("cloudy", "Cloudy"),
    }
}

fn day_json(slots: &[&Slot]) -> Value {
    let first = Local.timestamp_opt(slots[0].at, 0).single().unwrap_or_else(Local::now);
    let fold = |f: fn(&Slot) -> f64, pick: fn(f64, f64) -> f64, init: f64| slots.iter().map(|s| f(s)).fold(init, pick);
    // The slot nearest early afternoon represents the day as a whole.
    let noon = slots.iter().min_by_key(|s| (Local.timestamp_opt(s.at, 0).single().map(|t| t.hour() as i64).unwrap_or(0) - 13).abs()).unwrap_or(&slots[0]);
    // Hourly data is thinned to every third hour so a day is at most eight pills.
    let dense = slots.len() > 8;
    let hourly: Vec<Value> = slots
        .iter()
        .filter_map(|s| {
            let t = Local.timestamp_opt(s.at, 0).single()?;
            (!dense || t.hour() % 3 == 0).then(|| json!({ "time": t.format("%H:%M").to_string(), "hour": t.hour(), "at": s.at, "temp": s.temp, "condition": s.condition }))
        })
        .collect();
    json!({
        "date": first.format("%Y-%m-%d").to_string(), "day": first.format("%a").to_string(), "dayFull": first.format("%A").to_string(), "label": first.format("%-d %b").to_string(),
        "max": fold(|s| s.temp, f64::max, f64::MIN), "min": fold(|s| s.temp, f64::min, f64::MAX),
        "feels": fold(|s| s.feels, f64::max, f64::MIN), "wind": fold(|s| s.wind, f64::max, 0.0).round(),
        "humidity": (slots.iter().map(|s| s.humidity).sum::<f64>() / slots.len() as f64).round(),
        "pop": fold(|s| s.pop, f64::max, 0.0).round(),
        "condition": noon.condition, "desc": noon.desc, "hourly": hourly,
    })
}

/// Group slots into (up to five) local days.
fn days(slots: &[Slot]) -> Vec<Value> {
    let mut out: Vec<Value> = Vec::new();
    let mut current: Vec<&Slot> = Vec::new();
    let mut current_date = None;
    for s in slots {
        let date = Local.timestamp_opt(s.at, 0).single().map(|t| t.date_naive());
        if date != current_date && !current.is_empty() {
            out.push(day_json(&current));
            current.clear();
        }
        current_date = date;
        current.push(s);
    }
    if !current.is_empty() {
        out.push(day_json(&current));
    }
    out.truncate(5);
    out
}

fn slot_to_json(s: &Slot) -> Value {
    json!({ "at": s.at, "temp": s.temp, "feels": s.feels, "humidity": s.humidity, "wind": s.wind, "pop": s.pop, "condition": s.condition, "desc": s.desc })
}

/// Earlier slots of today are kept from the previous fetch: forecast APIs only
/// return the future, but the day view should still show this morning.
fn with_todays_history(mut fresh: Vec<Slot>) -> Vec<Slot> {
    const CONDITIONS: [&str; 10] = ["clear-day", "clear-night", "partly-day", "partly-night", "cloudy", "rain", "storm", "snow", "fog", "drizzle"];
    let midnight = Local::now().date_naive().and_hms_opt(0, 0, 0).and_then(|t| Local.from_local_datetime(&t).single()).map(|t| t.timestamp()).unwrap_or(0);
    let first_new = fresh.first().map(|s| s.at).unwrap_or(i64::MAX);
    let cached = util::read_json(&cache_file()).unwrap_or(Value::Null);
    let mut kept: Vec<Slot> = cached["slots"]
        .as_array()
        .map(|a| a.as_slice())
        .unwrap_or_default()
        .iter()
        .filter(|s| s["at"].as_i64().is_some_and(|at| at >= midnight && at < first_new))
        .map(|s| Slot {
            at: s["at"].as_i64().unwrap_or(0), temp: s["temp"].as_f64().unwrap_or(0.0), feels: s["feels"].as_f64().unwrap_or(0.0),
            humidity: s["humidity"].as_f64().unwrap_or(0.0), wind: s["wind"].as_f64().unwrap_or(0.0), pop: s["pop"].as_f64().unwrap_or(0.0),
            condition: CONDITIONS.iter().find(|c| Some(**c) == s["condition"].as_str()).copied().unwrap_or("cloudy"),
            desc: s["desc"].as_str().unwrap_or("").to_string(),
        })
        .collect();
    kept.append(&mut fresh);
    kept
}

fn fetch_owm(key: &str, city: &str, unit: &str) -> Result<Value> {
    let base = "https://api.openweathermap.org/data/2.5";
    let query = format!("appid={key}&id={city}&units={unit}");
    let forecast = get(format!("{base}/forecast?{query}"))?;
    let now = get(format!("{base}/weather?{query}"))?;
    let slots: Vec<Slot> = forecast["list"]
        .as_array()
        .ok_or_else(|| anyhow!("OpenWeatherMap: {}", forecast["message"].as_str().unwrap_or("unexpected reply")))?
        .iter()
        .map(|i| Slot {
            at: i["dt"].as_i64().unwrap_or(0), temp: i["main"]["temp"].as_f64().unwrap_or(0.0), feels: i["main"]["feels_like"].as_f64().unwrap_or(0.0),
            humidity: i["main"]["humidity"].as_f64().unwrap_or(0.0), wind: i["wind"]["speed"].as_f64().unwrap_or(0.0), pop: i["pop"].as_f64().unwrap_or(0.0) * 100.0,
            condition: owm_condition(i["weather"][0]["icon"].as_str().unwrap_or("")), desc: title_case(i["weather"][0]["description"].as_str().unwrap_or("")),
        })
        .collect();
    let slots = with_todays_history(slots);
    Ok(json!({
        "city": forecast["city"]["name"],
        "current": {
            "temp": now["main"]["temp"], "feels": now["main"]["feels_like"], "humidity": now["main"]["humidity"], "wind": now["wind"]["speed"],
            "condition": owm_condition(now["weather"][0]["icon"].as_str().unwrap_or("")), "desc": title_case(now["weather"][0]["description"].as_str().unwrap_or("")),
        },
        "days": days(&slots), "slots": slots.iter().map(slot_to_json).collect::<Vec<_>>(),
    }))
}

fn fetch_open_meteo(lat: f64, lon: f64, unit: &str) -> Result<Value> {
    let (temp_unit, wind_unit) = if unit == "imperial" { ("fahrenheit", "mph") } else { ("celsius", "ms") };
    let fields = "temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m,is_day";
    let url = format!("https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}&current={fields}&hourly={fields},precipitation_probability&forecast_days=5&timeformat=unixtime&timezone=auto&temperature_unit={temp_unit}&wind_speed_unit={wind_unit}");
    let data = get(url)?;
    let h = &data["hourly"];
    let times = h["time"].as_array().ok_or_else(|| anyhow!("Open-Meteo: {}", data["reason"].as_str().unwrap_or("unexpected reply")))?;
    let num = |field: &str, i: usize| h[field][i].as_f64().unwrap_or(0.0);
    let slots: Vec<Slot> = (0..times.len())
        .map(|i| {
            let (condition, desc) = wmo(num("weather_code", i) as i64, num("is_day", i) > 0.0);
            Slot { at: times[i].as_i64().unwrap_or(0), temp: num("temperature_2m", i), feels: num("apparent_temperature", i), humidity: num("relative_humidity_2m", i), wind: num("wind_speed_10m", i), pop: num("precipitation_probability", i), condition, desc: desc.to_string() }
        })
        .collect();
    let c = &data["current"];
    let (condition, desc) = wmo(c["weather_code"].as_i64().unwrap_or(3), c["is_day"].as_f64().unwrap_or(1.0) > 0.0);
    Ok(json!({
        "city": d().settings.str("weather.city"),
        "current": { "temp": c["temperature_2m"], "feels": c["apparent_temperature"], "humidity": c["relative_humidity_2m"], "wind": c["wind_speed_10m"], "condition": condition, "desc": desc },
        "days": days(&slots), "slots": [],
    }))
}

async fn fetch() -> Result<Value> {
    let s = &d().settings;
    let unit = match s.str("weather.unit").as_str() {
        "imperial" => "imperial",
        "standard" => "standard",
        _ => "metric",
    };
    let (key, city) = (s.str("weather.owmKey"), s.str("weather.owmCityId"));
    let (lat, lon) = (s.get("weather.lat").as_f64(), s.get("weather.lon").as_f64());
    let use_owm = s.str("weather.provider") == "openweathermap" && !key.is_empty() && !city.is_empty();
    let (provider, result) = if use_owm {
        ("openweathermap", tokio::task::spawn_blocking(move || fetch_owm(&key, &city, unit)).await?)
    } else if let (Some(lat), Some(lon)) = (lat, lon) {
        ("open-meteo", tokio::task::spawn_blocking(move || fetch_open_meteo(lat, lon, unit)).await?)
    } else {
        return Ok(json!({ "status": "unconfigured", "days": [], "current": null }));
    };
    let mut data = result?;
    let (temp_unit, wind_unit) = match unit {
        "imperial" => ("°F", "mph"),
        "standard" if provider == "openweathermap" => ("K", "m/s"),
        _ => ("°C", "m/s"),
    };
    data["status"] = json!("ok");
    data["provider"] = json!(provider);
    data["tempUnit"] = json!(temp_unit);
    data["windUnit"] = json!(wind_unit);
    data["updated"] = json!(util::now_s());
    Ok(data)
}

fn publish(data: &Value) {
    // Slots are bookkeeping for the next fetch, not something the UI needs.
    let mut public = data.clone();
    if let Some(obj) = public.as_object_mut() {
        obj.remove("slots");
    }
    d().hub.publish("weather", &public);
}

pub async fn run() -> Result<()> {
    let w = &d().weather;
    let cached = util::read_json(&cache_file());
    publish(cached.as_ref().unwrap_or(&json!({ "status": "loading", "days": [], "current": null })));
    tokio::spawn(async {
        let s = &d().settings;
        let mut rx = s.changes();
        let mut seen = s.get("weather");
        while rx.changed().await.is_ok() {
            if s.get("weather") != seen {
                seen = s.get("weather");
                d().weather.refresh.notify_one();
            }
        }
    });
    loop {
        let wait = match fetch().await {
            Ok(data) => {
                if data["status"] == "ok" {
                    let _ = util::write_json(&cache_file(), &data);
                }
                publish(&data);
                900
            }
            Err(e) => {
                log!("weather: {e:#}");
                // Keep showing the last good data; only report an error when there is none.
                if cached.is_none() && d().hub.get("weather").is_some_and(|w| w["status"] != "ok") {
                    publish(&json!({ "status": "error", "error": format!("{e:#}"), "days": [], "current": null }));
                }
                120
            }
        };
        tokio::select! {
            _ = tokio::time::sleep(Duration::from_secs(wait)) => {}
            _ = w.refresh.notified() => {}
        }
    }
}

pub async fn call(name: &str, p: &Value) -> Result<Value> {
    match name {
        "refresh" => d().weather.refresh.notify_one(),
        // Candidate places for a typed city name, for the settings page.
        "geocode" => {
            let query: String = p.str("name")?.bytes().map(|b| if b.is_ascii_alphanumeric() { (b as char).to_string() } else { format!("%{b:02X}") }).collect();
            let found = tokio::task::spawn_blocking(move || get(format!("https://geocoding-api.open-meteo.com/v1/search?name={query}&count=6"))).await??;
            let places: Vec<Value> = found["results"].as_array().map(|a| a.as_slice()).unwrap_or_default().iter().map(|r| json!({ "name": r["name"], "region": r["admin1"], "country": r["country"], "lat": r["latitude"], "lon": r["longitude"] })).collect();
            return Ok(json!(places));
        }
        _ => bail!("unknown method weather.{name}"),
    }
    Ok(Value::Null)
}
