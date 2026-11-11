//! Screen-time tracking.
//!
//! Once a second the focused application is charged one second, unless the
//! session is locked or idle. Totals live in SQLite, using the same schema as
//! the previous shell so its history carries over. The `focus` topic streams
//! today's statistics while a client wants it; `focus.stats` answers for any day.

use crate::util::Params;
use crate::{d, log, util};
use anyhow::{anyhow, Result};
use chrono::{Datelike, Duration as Days, Local, NaiveDate, Timelike};
use rusqlite::{params, Connection};
use serde_json::{json, Value};
use std::collections::HashMap;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Mutex;
use std::time::Duration;

/// Pseudo-applications that describe the session rather than something the user ran.
const SYSTEM_CLASSES: [&str; 5] = ["Desktop", "Locked", "Idle", "Unknown", "Quickshell"];

#[derive(Default)]
pub struct Focus {
    db: Mutex<Option<Connection>>,
    /// Seconds not yet written: (date, minute of day, class) → (seconds, display name).
    pending: Mutex<HashMap<(String, u32, String), (u64, String)>>,
    idle: AtomicBool,
}

const SCHEMA: &str = "
CREATE TABLE IF NOT EXISTS focus_log(log_date TEXT, app_class TEXT, seconds INTEGER, app_title TEXT, PRIMARY KEY(log_date, app_class));
CREATE INDEX IF NOT EXISTS idx_log_date ON focus_log(log_date);
CREATE TABLE IF NOT EXISTS focus_hourly(log_date TEXT, hour INTEGER, app_class TEXT, seconds INTEGER, PRIMARY KEY(log_date, hour, app_class));
CREATE TABLE IF NOT EXISTS focus_intervals(log_date TEXT, interval_idx INTEGER, app_class TEXT, seconds INTEGER, PRIMARY KEY(log_date, interval_idx, app_class));
CREATE TABLE IF NOT EXISTS focus_minutes(log_date TEXT, minute_idx INTEGER, app_class TEXT, seconds INTEGER, PRIMARY KEY(log_date, minute_idx, app_class));
";

fn open() -> Result<Connection> {
    let path = util::dirs().state.join("focus.db");
    let fresh = !path.exists();
    let conn = Connection::open(&path)?;
    conn.execute_batch("PRAGMA journal_mode=WAL; PRAGMA synchronous=NORMAL;")?;
    conn.execute_batch(SCHEMA)?;
    if fresh {
        // Bring over the history recorded by the previous shell, once.
        let old = util::home().join(".local/state/quickshell/focustime/focustime.db");
        if old.exists() {
            let import = || -> rusqlite::Result<()> {
                conn.execute("ATTACH DATABASE ?1 AS old", params![old.to_string_lossy()])?;
                for table in ["focus_log", "focus_hourly", "focus_intervals", "focus_minutes"] {
                    conn.execute_batch(&format!("INSERT OR IGNORE INTO {table} SELECT * FROM old.{table};"))?;
                }
                conn.execute_batch("DETACH DATABASE old;")
            };
            match import() {
                Ok(()) => log!("imported screen-time history from the previous shell"),
                Err(e) => log!("could not import old screen-time history: {e}"),
            }
        }
    }
    Ok(conn)
}

fn with_db<T>(f: impl FnOnce(&Connection) -> Result<T>) -> Result<T> {
    let mut guard = d().focus.db.lock().unwrap();
    if guard.is_none() {
        *guard = Some(open()?);
    }
    f(guard.as_ref().expect("opened above"))
}

/// Write buffered seconds to disk. Also called on shutdown.
pub fn flush() {
    let pending: Vec<_> = std::mem::take(&mut *d().focus.pending.lock().unwrap()).into_iter().collect();
    if pending.is_empty() {
        return;
    }
    let result = with_db(|conn| {
        let tx = conn.unchecked_transaction()?;
        for ((date, minute, class), (secs, name)) in &pending {
            let secs = *secs as i64;
            tx.execute("INSERT INTO focus_log VALUES(?1, ?2, ?3, ?4) ON CONFLICT(log_date, app_class) DO UPDATE SET seconds = seconds + ?3, app_title = ?4", params![date, class, secs, name])?;
            tx.execute("INSERT INTO focus_hourly VALUES(?1, ?2, ?3, ?4) ON CONFLICT(log_date, hour, app_class) DO UPDATE SET seconds = seconds + ?4", params![date, minute / 60, class, secs])?;
            tx.execute("INSERT INTO focus_intervals VALUES(?1, ?2, ?3, ?4) ON CONFLICT(log_date, interval_idx, app_class) DO UPDATE SET seconds = seconds + ?4", params![date, minute / 15, class, secs])?;
            tx.execute("INSERT INTO focus_minutes VALUES(?1, ?2, ?3, ?4) ON CONFLICT(log_date, minute_idx, app_class) DO UPDATE SET seconds = seconds + ?4", params![date, minute, class, secs])?;
        }
        tx.commit()?;
        Ok(())
    });
    if let Err(e) = result {
        log!("saving screen time: {e:#}");
    }
}

/// What is being used right now: (class, display name), or None when nothing should be counted.
fn current_app() -> Option<(String, String)> {
    let f = &d().focus;
    let count_system = d().settings.flag("focus.countSystem");
    let system = |label: &str| count_system.then(|| (label.to_string(), label.to_string()));
    if super::power::is_locked() {
        return system("Locked");
    }
    if f.idle.load(Ordering::Relaxed) {
        return system("Idle");
    }
    let (class, title) = d().hypr.focused_window();
    if class.is_empty() {
        return system("Desktop");
    }
    let name = d().apps.resolve(&class).map(|(name, _)| name).unwrap_or_else(|| {
        // No desktop entry: the last segment of the title is usually the application name.
        let tail = title.rsplit([' ']).next().unwrap_or("");
        let from_title = title.rsplit(" - ").next().or(title.rsplit(" — ").next()).unwrap_or(tail).trim();
        if !from_title.is_empty() && from_title.len() <= 25 {
            from_title.to_string()
        } else {
            let mut c = class.chars();
            c.next().map(|first| first.to_uppercase().collect::<String>() + c.as_str()).unwrap_or_default()
        }
    });
    Some((class, name))
}

fn fmt_date(date: NaiveDate) -> String {
    date.format("%Y-%m-%d").to_string()
}

fn stats(date: NaiveDate, app: Option<&str>) -> Result<Value> {
    flush();
    let exclude_system = !d().settings.flag("focus.countSystem");
    // One WHERE fragment shared by every query: optional app filter, optional system exclusion.
    let mut filter = String::new();
    if let Some(app) = app {
        filter.push_str(&format!(" AND app_class = '{}'", app.replace('\'', "''")));
    } else if exclude_system {
        filter.push_str(&format!(" AND app_class NOT IN ({})", SYSTEM_CLASSES.map(|c| format!("'{c}'")).join(",")));
    }

    with_db(|conn| {
        let day_total = |day: NaiveDate| -> Result<i64> {
            Ok(conn.query_row(&format!("SELECT COALESCE(SUM(seconds), 0) FROM focus_log WHERE log_date = ?1{filter}"), params![fmt_date(day)], |r| r.get(0))?)
        };
        let apps_between = |from: NaiveDate, to: NaiveDate, limit: usize| -> Result<Vec<Value>> {
            let mut stmt = conn.prepare(&format!("SELECT app_class, MAX(app_title), SUM(seconds) AS s FROM focus_log WHERE log_date BETWEEN ?1 AND ?2{filter} GROUP BY app_class ORDER BY s DESC LIMIT {limit}"))?;
            let rows: Vec<(String, Option<String>, i64)> = stmt.query_map(params![fmt_date(from), fmt_date(to)], |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?)))?.filter_map(Result::ok).collect();
            let sum: i64 = rows.iter().map(|r| r.2).sum::<i64>().max(1);
            Ok(rows
                .into_iter()
                .map(|(class, title, seconds)| {
                    let resolved = d().apps.resolve(&class);
                    let name = title.filter(|t| !t.is_empty()).or(resolved.as_ref().map(|r| r.0.clone())).unwrap_or_else(|| class.clone());
                    json!({ "class": class, "name": name, "icon": resolved.map(|r| r.1).unwrap_or_default(), "seconds": seconds, "percent": (seconds as f64 / sum as f64 * 1000.0).round() / 10.0 })
                })
                .collect())
        };

        let monday = date - Days::days(date.weekday().num_days_from_monday() as i64);
        let sunday = monday + Days::days(6);
        let mut week = Vec::new();
        let (mut week_total, mut active_days) = (0, 0);
        for i in 0..7 {
            let day = monday + Days::days(i);
            let total = day_total(day)?;
            week_total += total;
            active_days += (total > 0) as i64;
            week.push(json!({ "date": fmt_date(day), "day": day.format("%a").to_string(), "total": total, "selected": day == date }));
        }

        let first = date.with_day(1).ok_or_else(|| anyhow!("bad date"))?;
        let mut month = Vec::new();
        let mut day = first;
        while day.month() == first.month() {
            month.push(json!({ "date": fmt_date(day), "total": day_total(day)?, "selected": day == date }));
            day += Days::days(1);
        }

        let mut half_hours = vec![0i64; 48];
        let mut stmt = conn.prepare(&format!("SELECT interval_idx, SUM(seconds) FROM focus_intervals WHERE log_date = ?1{filter} GROUP BY interval_idx"))?;
        for (idx, secs) in stmt.query_map(params![fmt_date(date)], |r| Ok((r.get::<_, i64>(0)?, r.get::<_, i64>(1)?)))?.flatten() {
            if let Some(slot) = half_hours.get_mut((idx / 2) as usize) {
                *slot += secs;
            }
        }

        let mut heatmap = vec![vec![0i64; 24]; 7];
        let mut stmt = conn.prepare(&format!("SELECT log_date, hour, SUM(seconds) FROM focus_hourly WHERE log_date BETWEEN ?1 AND ?2{filter} GROUP BY log_date, hour"))?;
        for (day, hour, secs) in stmt.query_map(params![fmt_date(monday), fmt_date(sunday)], |r| Ok((r.get::<_, String>(0)?, r.get::<_, i64>(1)?, r.get::<_, i64>(2)?)))?.flatten() {
            if let Ok(parsed) = NaiveDate::parse_from_str(&day, "%Y-%m-%d") {
                let row = parsed.weekday().num_days_from_monday() as usize;
                if let Some(cell) = heatmap[row].get_mut(hour as usize) {
                    *cell += secs;
                }
            }
        }

        Ok(json!({
            "date": fmt_date(date),
            "today": fmt_date(Local::now().date_naive()),
            "app": app,
            "total": day_total(date)?,
            "yesterday": day_total(date - Days::days(1))?,
            "average": if active_days > 0 { week_total / active_days } else { 0 },
            "weekRange": format!("{} - {}", monday.format("%b %-d"), sunday.format("%b %-d")),
            "apps": apps_between(date, date, 200)?,
            "weekApps": apps_between(monday, sunday, 50)?,
            "week": week,
            "month": month,
            "monthOffset": first.weekday().num_days_from_monday(),
            "monthName": first.format("%B %Y").to_string(),
            "halfHours": half_hours,
            "heatmap": heatmap,
            "current": current_app().map(|(_, name)| name),
        }))
    })
}

pub async fn run() -> Result<()> {
    // Open (and possibly import) up front so the first popup open is instant.
    tokio::task::spawn_blocking(|| with_db(|_| Ok(()))).await??;
    let f = &d().focus;
    let mut tick = 0u64;
    let mut interval = tokio::time::interval(Duration::from_secs(1));
    interval.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Skip);
    let mut was_wanted = false;
    loop {
        interval.tick().await;
        tick += 1;
        if let Some((class, name)) = current_app() {
            let now = Local::now();
            let key = (fmt_date(now.date_naive()), now.hour() * 60 + now.minute(), class);
            let mut pending = f.pending.lock().unwrap();
            let entry = pending.entry(key).or_insert((0, String::new()));
            entry.0 += 1;
            entry.1 = name;
        }
        if tick % 15 == 0 {
            tokio::task::spawn_blocking(flush).await?;
        }
        // Live statistics for an open popup: at once when it opens, then every few seconds.
        let wanted = d().hub.is_wanted("focus");
        let just_opened = wanted && !was_wanted;
        was_wanted = wanted;
        if wanted && (just_opened || tick % 3 == 0) {
            if let Ok(Ok(today)) = tokio::task::spawn_blocking(|| stats(Local::now().date_naive(), None)).await {
                d().hub.publish("focus", &today);
            }
        }
    }
}

pub async fn call(name: &str, p: &Value) -> Result<Value> {
    match name {
        "stats" => {
            let date = match p.get("date").and_then(Value::as_str) {
                Some(s) => NaiveDate::parse_from_str(s, "%Y-%m-%d").map_err(|_| anyhow!("date must be YYYY-MM-DD"))?,
                None => Local::now().date_naive(),
            };
            let app = p.get("app").and_then(Value::as_str).filter(|a| !a.is_empty()).map(String::from);
            tokio::task::spawn_blocking(move || stats(date, app.as_deref())).await?
        }
        // The UI reports when the user has been away from keyboard and mouse.
        "setIdle" => {
            d().focus.idle.store(p.flag("idle")?, Ordering::Relaxed);
            Ok(Value::Null)
        }
        _ => Err(anyhow!("unknown method focus.{name}")),
    }
}
