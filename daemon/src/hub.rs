//! The state hub: every module publishes its state here, every UI client reads from here.
//!
//! * `publish(topic, data)` stores the latest state of a topic and broadcasts it,
//!   but only if it actually changed. Modules can therefore republish freely.
//! * `emit(event, data)` broadcasts a one-off event (nothing is stored).
//! * "Wanted" topics are expensive ones (system stats, Wi-Fi scans, ...) that a
//!   module only produces while at least one client has asked for them.

use serde::Serialize;
use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use tokio::sync::{broadcast, Notify};

pub type Line = Arc<str>;

pub struct Hub {
    states: Mutex<HashMap<String, Line>>,
    tx: broadcast::Sender<Line>,
    wants: Mutex<HashMap<String, usize>>,
    wants_changed: Notify,
}

impl Default for Hub {
    fn default() -> Self {
        let (tx, _) = broadcast::channel(512);
        Hub { states: Mutex::new(HashMap::new()), tx, wants: Mutex::new(HashMap::new()), wants_changed: Notify::new() }
    }
}

impl Hub {
    /// Store and broadcast the state of `topic`. No-op when nothing changed.
    pub fn publish<T: Serialize + ?Sized>(&self, topic: &str, data: &T) {
        let body = match serde_json::to_string(data) {
            Ok(b) => b,
            Err(e) => return crate::log!("cannot serialize topic {topic}: {e}"),
        };
        let line: Line = format!("{{\"t\":\"{topic}\",\"d\":{body}}}").into();
        {
            let mut states = self.states.lock().unwrap();
            if states.get(topic).is_some_and(|old| **old == *line) {
                return;
            }
            states.insert(topic.to_string(), line.clone());
        }
        let _ = self.tx.send(line);
    }

    /// Broadcast a transient event.
    pub fn emit<T: Serialize + ?Sized>(&self, event: &str, data: &T) {
        match serde_json::to_string(data) {
            Ok(body) => {
                let _ = self.tx.send(format!("{{\"e\":\"{event}\",\"d\":{body}}}").into());
            }
            Err(e) => crate::log!("cannot serialize event {event}: {e}"),
        }
    }

    /// Short user-facing message shown by the shell as a toast.
    pub fn toast(&self, kind: &str, title: &str, body: &str) {
        self.emit("toast", &serde_json::json!({ "kind": kind, "title": title, "body": body }));
    }

    pub fn subscribe(&self) -> broadcast::Receiver<Line> {
        self.tx.subscribe()
    }

    /// How many clients are listening.
    pub fn subscribers(&self) -> usize {
        self.tx.receiver_count()
    }

    /// Latest line of every topic, for a client that just connected.
    pub fn snapshot(&self) -> Vec<Line> {
        self.states.lock().unwrap().values().cloned().collect()
    }

    /// The latest state of one topic as parsed JSON.
    pub fn get(&self, topic: &str) -> Option<serde_json::Value> {
        let line = self.states.lock().unwrap().get(topic).cloned()?;
        let mut v: serde_json::Value = serde_json::from_str(&line).ok()?;
        v.get_mut("d").map(serde_json::Value::take)
    }

    pub fn want(&self, topic: &str) {
        *self.wants.lock().unwrap().entry(topic.to_string()).or_insert(0) += 1;
        self.wants_changed.notify_waiters();
    }

    pub fn unwant(&self, topic: &str) {
        let mut wants = self.wants.lock().unwrap();
        if let Some(n) = wants.get_mut(topic) {
            *n = n.saturating_sub(1);
        }
        drop(wants);
        self.wants_changed.notify_waiters();
    }

    pub fn is_wanted(&self, topic: &str) -> bool {
        self.wants.lock().unwrap().get(topic).copied().unwrap_or(0) > 0
    }

    /// Resolves once somebody wants `topic`.
    pub async fn wait_wanted(&self, topic: &str) {
        loop {
            let notified = self.wants_changed.notified();
            if self.is_wanted(topic) {
                return;
            }
            notified.await;
        }
    }

    /// Resolves once the wanted-ness of `topic` differs from `current`.
    pub async fn wait_wanted_change(&self, topic: &str, current: bool) {
        loop {
            let notified = self.wants_changed.notified();
            if self.is_wanted(topic) != current {
                return;
            }
            notified.await;
        }
    }
}
