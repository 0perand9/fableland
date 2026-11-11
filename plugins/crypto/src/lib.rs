//! Coin prices from CoinGecko's public API, for the bar.
//!
//! Publishes the `crypto` topic every `crypto.intervalMinutes` (and at once
//! when the settings change); `crypto.refresh` asks for new prices now.

use fable_plugin::tokio::sync::Notify;
use fable_plugin::tokio::time::{sleep_until, Duration, Instant};
use fable_plugin::util::{now_s, url_encode};
use fable_plugin::*;

const API: &str = "https://api.coingecko.com/api/v3";

/// Wakes the task for `refresh`.
static WAKE: Notify = Notify::const_new();

pub fn plugin() -> Plugin {
    Plugin::new().run(run).call(|ctx, method, _| async move {
        match method.as_str() {
            "refresh" => {
                WAKE.notify_one();
                Ok(Value::Null)
            }
            _ => bail!("unknown method {}.{method}", ctx.name()),
        }
    })
}

/// The coins to follow: CoinGecko ids, separated by commas or spaces.
fn coins(ctx: &Ctx) -> Vec<String> {
    ctx.setting_str("coins").split([',', ' ']).map(|c| c.trim().to_lowercase()).filter(|c| !c.is_empty()).collect()
}

fn currency(ctx: &Ctx) -> String {
    Some(ctx.setting_str("currency").trim().to_lowercase()).filter(|c| !c.is_empty()).unwrap_or_else(|| "usd".into())
}

async fn fetch(ids: &[String], currency: &str) -> Result<Vec<Value>> {
    let url = format!("{API}/coins/markets?vs_currency={}&ids={}", url_encode(currency), url_encode(&ids.join(",")));
    let reply = http::get(url).json().await?;
    let markets = reply.as_array().ok_or_else(|| anyhow!("CoinGecko sent no prices"))?;
    // In the order the settings list them.
    Ok(ids
        .iter()
        .filter_map(|id| markets.iter().find(|m| m["id"].as_str() == Some(id)))
        .map(|m| json!({ "id": m["id"], "symbol": m["symbol"].as_str().unwrap_or("").to_uppercase(), "name": m["name"], "price": m["current_price"], "change": m["price_change_percentage_24h"] }))
        .collect())
}

async fn run(ctx: Ctx) -> Result<()> {
    let mut changes = ctx.setting_changes();
    let mut last: Vec<Value> = Vec::new();
    let mut asked = (Vec::new(), String::new());
    loop {
        let (ids, currency) = (coins(&ctx), currency(&ctx));
        // Old prices in another currency, or of coins no longer followed, would mislead.
        if asked != (ids.clone(), currency.clone()) {
            last.clear();
        }
        asked = (ids.clone(), currency.clone());
        let mut wait = Duration::from_secs(60 * ctx.setting("intervalMinutes").as_u64().unwrap_or(5).max(1));
        let error = if ids.is_empty() {
            String::new()
        } else {
            match fetch(&ids, &currency).await {
                Ok(prices) => {
                    last = prices;
                    String::new()
                }
                Err(e) => {
                    // Try again soon, but not so soon that the free API turns us away.
                    wait = wait.min(Duration::from_secs(60));
                    format!("{e:#}")
                }
            }
        };
        ctx.publish(json!({ "currency": currency, "coins": last, "updated": now_s(), "error": error }));
        // `changes` fires when any setting changes; only a change of ours counts.
        let (before, due) = (ctx.settings(), Instant::now() + wait);
        loop {
            tokio::select! {
                _ = sleep_until(due) => break,
                _ = WAKE.notified() => break,
                changed = changes.changed() => {
                    if changed.is_err() {
                        return Ok(());
                    }
                    if ctx.settings() != before {
                        break;
                    }
                }
            }
        }
    }
}
