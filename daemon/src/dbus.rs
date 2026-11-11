//! Thin D-Bus helpers. Property bags are converted to `serde_json::Value` so the
//! modules can use one data model for everything they handle.

use anyhow::Result;
use futures_util::StreamExt;
use serde_json::{json, Value as Json};
use std::collections::HashMap;
use zbus::zvariant::{OwnedValue, Value};
use zbus::Connection;

pub type Props = HashMap<String, OwnedValue>;

const PROPERTIES: &str = "org.freedesktop.DBus.Properties";

pub fn to_json(v: &Value) -> Json {
    match v {
        Value::U8(n) => json!(n),
        Value::Bool(b) => json!(b),
        Value::I16(n) => json!(n),
        Value::U16(n) => json!(n),
        Value::I32(n) => json!(n),
        Value::U32(n) => json!(n),
        Value::I64(n) => json!(n),
        Value::U64(n) => json!(n),
        Value::F64(n) => json!(n),
        Value::Str(s) => json!(s.as_str()),
        Value::Signature(s) => json!(s.to_string()),
        Value::ObjectPath(p) => json!(p.as_str()),
        Value::Value(inner) => to_json(inner),
        Value::Array(a) => Json::Array(a.iter().map(to_json).collect()),
        Value::Dict(d) => {
            let mut map = serde_json::Map::new();
            for (k, val) in d.iter() {
                let key = match to_json(k) {
                    Json::String(s) => s,
                    other => other.to_string(),
                };
                map.insert(key, to_json(val));
            }
            Json::Object(map)
        }
        Value::Structure(s) => Json::Array(s.fields().iter().map(to_json).collect()),
        _ => Json::Null,
    }
}

pub fn props_to_json(props: &Props) -> Json {
    Json::Object(props.iter().map(|(k, v)| (k.clone(), to_json(v))).collect())
}

/// A byte array property (`ay`) as bytes, without going through JSON.
pub fn bytes(v: &Value) -> Option<Vec<u8>> {
    match v {
        Value::Value(inner) => bytes(inner),
        Value::Array(a) => a.iter().map(|b| if let Value::U8(n) = b { Some(*n) } else { None }).collect(),
        _ => None,
    }
}

/// All properties of one interface as a JSON object.
pub async fn get_all(conn: &Connection, dest: &str, path: &str, iface: &str) -> Result<Json> {
    let reply = conn.call_method(Some(dest), path, Some(PROPERTIES), "GetAll", &(iface,)).await?;
    let props: Props = reply.body().deserialize()?;
    Ok(props_to_json(&props))
}

pub async fn set<'a>(conn: &Connection, dest: &str, path: &str, iface: &str, prop: &str, value: Value<'a>) -> Result<()> {
    conn.call_method(Some(dest), path, Some(PROPERTIES), "Set", &(iface, prop, value)).await?;
    Ok(())
}

/// Invoke `on_signal` for every signal emitted by `sender` (optionally limited to
/// a path namespace). The callback receives (path, interface, member).
pub async fn watch_signals<F>(conn: &Connection, sender: &str, path_namespace: Option<&str>, mut on_signal: F) -> Result<()>
where
    F: FnMut(&str, &str, &str),
{
    let mut rule = zbus::MatchRule::builder().msg_type(zbus::message::Type::Signal).sender(sender)?;
    if let Some(ns) = path_namespace {
        rule = rule.path_namespace(ns)?;
    }
    watch_rule(conn, rule.build(), |p, i, m, _| on_signal(p, i, m)).await
}

/// Like [`watch_signals`] for an arbitrary match rule. The callback also gets the sender's unique name.
pub async fn watch_rule<F>(conn: &Connection, rule: zbus::MatchRule<'_>, mut on_signal: F) -> Result<()>
where
    F: FnMut(&str, &str, &str, &str),
{
    let mut stream = zbus::MessageStream::for_match_rule(rule, conn, Some(256)).await?;
    while let Some(msg) = stream.next().await {
        let Ok(msg) = msg else { continue };
        let header = msg.header();
        on_signal(
            header.path().map(|p| p.as_str()).unwrap_or(""),
            header.interface().map(|i| i.as_str()).unwrap_or(""),
            header.member().map(|m| m.as_str()).unwrap_or(""),
            header.sender().map(|s| s.as_str()).unwrap_or(""),
        );
    }
    Ok(())
}

/// Shared connections, opened lazily. A missing bus is an error for the caller, not a panic.
pub async fn system() -> Result<Connection> {
    static CONN: tokio::sync::OnceCell<Connection> = tokio::sync::OnceCell::const_new();
    Ok(CONN.get_or_try_init(Connection::system).await?.clone())
}

pub async fn session() -> Result<Connection> {
    static CONN: tokio::sync::OnceCell<Connection> = tokio::sync::OnceCell::const_new();
    Ok(CONN.get_or_try_init(Connection::session).await?.clone())
}
