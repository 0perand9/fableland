//! The one socket everything talks through.
//!
//! Wire format: one JSON object per line.
//!
//! client → daemon   {"id": 7, "m": "audio.setVolume", "p": {...}}   (id optional)
//! daemon → client   {"id": 7, "ok": true, "r": ...} | {"id": 7, "ok": false, "err": "..."}
//!                   {"t": "audio", "d": {...}}      state of a topic (after "sub")
//!                   {"e": "toast", "d": {...}}      one-off event (after "sub")
//!
//! Built-in methods: `sub` (start receiving state + events), `want`/`unwant`
//! {topic} (reference-count an on-demand topic for this connection), `get` {topic}.

use crate::{d, hub::Line, log, util};
use anyhow::Result;
use serde_json::{json, Value};
use std::future::pending;
use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::net::{UnixListener, UnixStream};
use tokio::sync::{broadcast, mpsc};

pub async fn serve() -> Result<()> {
    let path = util::socket_path();
    if path.exists() {
        // A live daemon answers; a stale socket file from a crash does not.
        if UnixStream::connect(&path).await.is_ok() {
            anyhow::bail!("another fable daemon is already running on {}", path.display());
        }
        let _ = std::fs::remove_file(&path);
    }
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent)?;
    }
    let listener = UnixListener::bind(&path)?;
    log!("listening on {}", path.display());
    loop {
        let (stream, _) = listener.accept().await?;
        tokio::spawn(async move {
            if let Err(e) = connection(stream).await {
                log!("client error: {e:#}");
            }
        });
    }
}

async fn connection(stream: UnixStream) -> Result<()> {
    let (reader, mut writer) = stream.into_split();
    let mut lines = BufReader::new(reader).lines();
    let (reply_tx, mut reply_rx) = mpsc::unbounded_channel::<String>();
    let mut bus: Option<broadcast::Receiver<Line>> = None;
    let mut wants: Vec<String> = Vec::new();
    let hub = &d().hub;

    let result: Result<()> = async {
        loop {
            tokio::select! {
                line = lines.next_line() => {
                    let Some(line) = line? else { break };
                    if line.trim().is_empty() { continue; }
                    let req: Value = match serde_json::from_str(&line) {
                        Ok(v) => v,
                        Err(e) => { send(&mut writer, &json!({"ok": false, "err": format!("bad json: {e}")}).to_string()).await?; continue; }
                    };
                    let id = req.get("id").cloned();
                    let method = req.get("m").and_then(Value::as_str).unwrap_or("").to_string();
                    let params = req.get("p").cloned().unwrap_or(Value::Null);
                    match method.as_str() {
                        "sub" => {
                            bus = Some(hub.subscribe());
                            for l in hub.snapshot() { send(&mut writer, &l).await?; }
                            reply(&reply_tx, id, Ok(Value::Null));
                        }
                        "want" | "unwant" => {
                            let topic = params.get("topic").and_then(Value::as_str).unwrap_or("").to_string();
                            if method == "want" {
                                hub.want(&topic);
                                wants.push(topic);
                            } else if let Some(i) = wants.iter().position(|t| *t == topic) {
                                wants.swap_remove(i);
                                hub.unwant(&topic);
                            }
                            reply(&reply_tx, id, Ok(Value::Null));
                        }
                        "get" => {
                            let topic = params.get("topic").and_then(Value::as_str).unwrap_or("");
                            reply(&reply_tx, id, hub.get(topic).ok_or_else(|| anyhow::anyhow!("unknown topic '{topic}'")));
                        }
                        _ => {
                            // Each request runs on its own task so a slow one never blocks the rest.
                            let tx = reply_tx.clone();
                            tokio::spawn(async move {
                                let res = crate::dispatch(&method, &params).await;
                                if let Err(e) = &res {
                                    log!("{method} failed: {e:#}");
                                    if id.is_none() {
                                        d().hub.toast("error", &method, &format!("{e:#}"));
                                    }
                                }
                                reply(&tx, id, res);
                            });
                        }
                    }
                }
                Some(msg) = reply_rx.recv() => send(&mut writer, &msg).await?,
                msg = async { match &mut bus { Some(b) => b.recv().await, None => pending().await } } => match msg {
                    Ok(l) => send(&mut writer, &l).await?,
                    // Fell too far behind: the stored states are still authoritative, so resync from them.
                    Err(broadcast::error::RecvError::Lagged(_)) => {
                        for l in hub.snapshot() { send(&mut writer, &l).await?; }
                    }
                    Err(broadcast::error::RecvError::Closed) => break,
                },
            }
        }
        Ok(())
    }
    .await;

    for topic in wants {
        hub.unwant(&topic);
    }
    result
}

fn reply(tx: &mpsc::UnboundedSender<String>, id: Option<Value>, res: Result<Value>) {
    let Some(id) = id else { return };
    let msg = match res {
        Ok(r) => json!({"id": id, "ok": true, "r": r}),
        Err(e) => json!({"id": id, "ok": false, "err": format!("{e:#}")}),
    };
    let _ = tx.send(msg.to_string());
}

async fn send(writer: &mut tokio::net::unix::OwnedWriteHalf, line: &str) -> Result<()> {
    writer.write_all(line.as_bytes()).await?;
    writer.write_all(b"\n").await?;
    Ok(())
}
