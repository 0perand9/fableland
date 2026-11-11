//! Countdown timer, stopwatch and pomodoro (`timers` topic).
//!
//! State is absolute (end timestamps), persisted, and owned here, so a running
//! timer survives UI and daemon restarts and is the same on every monitor.
//! The UI animates the digits itself from `endsAt` / `startedAt`.

use super::notif::{self, Note};
use crate::util::Params;
use crate::{d, util};
use anyhow::{bail, Result};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::sync::Mutex;
use std::time::Duration;
use tokio::sync::Notify;

#[derive(Clone, Serialize, Deserialize)]
#[serde(default)]
struct State {
    // Countdown: `timer_ends` is 0 while paused, and `timer_left` holds what remains.
    timer_preset: u64,
    timer_left: u64,
    timer_ends: u64,
    // Stopwatch: `sw_started` is 0 while stopped.
    sw_started: u64,
    sw_elapsed: u64,
    sw_laps: Vec<(u64, u64)>,
    // Pomodoro: phase 0 = focus, 1 = short break, 2 = long break.
    pomo_phase: u8,
    pomo_left: u64,
    pomo_ends: u64,
    pomo_session: u32,
    pomo_sessions: u32,
    pomo_work: u64,
    pomo_short: u64,
    pomo_long: u64,
}

impl Default for State {
    fn default() -> Self {
        State { timer_preset: 300_000, timer_left: 300_000, timer_ends: 0, sw_started: 0, sw_elapsed: 0, sw_laps: Vec::new(), pomo_phase: 0, pomo_left: 25 * 60_000, pomo_ends: 0, pomo_session: 0, pomo_sessions: 4, pomo_work: 25, pomo_short: 5, pomo_long: 15 }
    }
}

impl State {
    fn phase_length(&self, phase: u8) -> u64 {
        60_000 * match phase {
            0 => self.pomo_work,
            1 => self.pomo_short,
            _ => self.pomo_long,
        }
    }
}

#[derive(Default)]
pub struct Timers {
    state: Mutex<State>,
    changed: Notify,
}

fn file() -> std::path::PathBuf {
    util::dirs().state.join("timers.json")
}

fn publish(s: &State) {
    let phase = ["focus", "short", "long"][s.pomo_phase.min(2) as usize];
    d().hub.publish(
        "timers",
        &json!({
            "timer": { "presetMs": s.timer_preset, "remainingMs": s.timer_left, "endsAt": s.timer_ends, "running": s.timer_ends > 0 },
            "stopwatch": { "running": s.sw_started > 0, "startedAt": s.sw_started, "elapsedMs": s.sw_elapsed, "laps": s.sw_laps.iter().map(|(total, diff)| json!({ "total": total, "diff": diff })).collect::<Vec<_>>() },
            "pomodoro": {
                "phase": phase, "remainingMs": s.pomo_left, "endsAt": s.pomo_ends, "running": s.pomo_ends > 0,
                "session": s.pomo_session, "sessions": s.pomo_sessions, "workMin": s.pomo_work, "shortMin": s.pomo_short, "longMin": s.pomo_long,
            },
        }),
    );
}

/// Apply a change, then persist, publish and reschedule.
fn update(f: impl FnOnce(&mut State)) {
    let t = &d().timers;
    let snapshot = {
        let mut s = t.state.lock().unwrap();
        f(&mut s);
        s.clone()
    };
    let _ = util::write_json(&file(), &serde_json::to_value(&snapshot).unwrap_or(Value::Null));
    publish(&snapshot);
    t.changed.notify_one();
}

fn alert(summary: &str, body: &str, icon: &str) {
    notif::notify(Note { app: "Timer", summary, body, icon, image: "", actions: vec![] });
    super::misc::play_sound("alarm");
}

fn fmt(ms: u64) -> String {
    let s = ms / 1000;
    if s >= 3600 {
        format!("{}:{:02}:{:02}", s / 3600, s % 3600 / 60, s % 60)
    } else {
        format!("{:02}:{:02}", s / 60, s % 60)
    }
}

/// Fire whatever has reached its end time.
fn fire_due() {
    let now = util::now_ms();
    update(|s| {
        if s.timer_ends > 0 && s.timer_ends <= now {
            alert("Timer finished", &format!("Your {} timer is done.", fmt(s.timer_preset)), "preferences-system-time");
            s.timer_ends = 0;
            s.timer_left = s.timer_preset;
        }
        if s.pomo_ends > 0 && s.pomo_ends <= now {
            s.pomo_ends = 0;
            if s.pomo_phase == 0 {
                s.pomo_session += 1;
                // A long break closes each full round of focus sessions.
                if s.pomo_session >= s.pomo_sessions {
                    s.pomo_session = 0;
                    s.pomo_phase = 2;
                } else {
                    s.pomo_phase = 1;
                }
                alert("Focus complete", "Great job! Time for a well-deserved break.", "face-smile");
            } else {
                s.pomo_phase = 0;
                alert("Break over", "Let's get back to focus.", "task-due");
            }
            s.pomo_left = s.phase_length(s.pomo_phase);
        }
    });
}

pub async fn run() -> Result<()> {
    let t = &d().timers;
    if let Some(saved) = util::read_json(&file()).and_then(|v| serde_json::from_value::<State>(v).ok()) {
        *t.state.lock().unwrap() = saved;
    }
    publish(&t.state.lock().unwrap().clone());
    loop {
        let next = {
            let s = t.state.lock().unwrap();
            [s.timer_ends, s.pomo_ends].into_iter().filter(|e| *e > 0).min()
        };
        match next {
            Some(at) => {
                let wait = Duration::from_millis(at.saturating_sub(util::now_ms()));
                tokio::select! {
                    _ = tokio::time::sleep(wait) => fire_due(),
                    _ = t.changed.notified() => {}
                }
            }
            None => t.changed.notified().await,
        }
    }
}

pub async fn call(name: &str, p: &Value) -> Result<Value> {
    let now = util::now_ms();
    match name {
        // ---- countdown
        "timerSet" => {
            let ms = (p.num("ms")?.max(0.0) as u64).min(99 * 3_600_000 + 59 * 60_000 + 59_000);
            update(|s| {
                s.timer_preset = ms;
                s.timer_left = ms;
                s.timer_ends = 0;
            })
        }
        "timerStart" => update(|s| {
            // Starting an empty timer would "finish" instantly; ignore it.
            if s.timer_ends == 0 && s.timer_left > 0 {
                s.timer_ends = now + s.timer_left;
            }
        }),
        "timerPause" => update(|s| {
            if s.timer_ends > 0 {
                s.timer_left = s.timer_ends.saturating_sub(now);
                s.timer_ends = 0;
            }
        }),
        "timerReset" => update(|s| {
            s.timer_ends = 0;
            s.timer_left = s.timer_preset;
        }),
        // ---- stopwatch
        "stopwatchStart" => update(|s| {
            if s.sw_started == 0 {
                s.sw_started = now;
            }
        }),
        "stopwatchPause" => update(|s| {
            if s.sw_started > 0 {
                s.sw_elapsed += now.saturating_sub(s.sw_started);
                s.sw_started = 0;
            }
        }),
        "stopwatchLap" => update(|s| {
            if s.sw_started > 0 {
                let total = s.sw_elapsed + now.saturating_sub(s.sw_started);
                let previous = s.sw_laps.last().map(|l| l.0).unwrap_or(0);
                s.sw_laps.push((total, total - previous));
            }
        }),
        "stopwatchReset" => update(|s| {
            s.sw_started = 0;
            s.sw_elapsed = 0;
            s.sw_laps.clear();
        }),
        // ---- pomodoro
        "pomodoroStart" => update(|s| {
            if s.pomo_ends == 0 && s.pomo_left > 0 {
                s.pomo_ends = now + s.pomo_left;
            }
        }),
        "pomodoroPause" => update(|s| {
            if s.pomo_ends > 0 {
                s.pomo_left = s.pomo_ends.saturating_sub(now);
                s.pomo_ends = 0;
            }
        }),
        "pomodoroSkip" => update(|s| {
            s.pomo_ends = 0;
            s.pomo_phase = if s.pomo_phase == 0 { 1 } else { 0 };
            s.pomo_left = s.phase_length(s.pomo_phase);
        }),
        "pomodoroReset" => update(|s| {
            s.pomo_ends = 0;
            s.pomo_phase = 0;
            s.pomo_session = 0;
            s.pomo_left = s.phase_length(0);
        }),
        "pomodoroConfig" => {
            let get = |key: &str, lo: f64, hi: f64, current: u64| p.get(key).and_then(Value::as_f64).map(|v| v.clamp(lo, hi) as u64).unwrap_or(current);
            update(|s| {
                s.pomo_work = get("workMin", 1.0, 120.0, s.pomo_work);
                s.pomo_short = get("shortMin", 1.0, 60.0, s.pomo_short);
                s.pomo_long = get("longMin", 1.0, 90.0, s.pomo_long);
                s.pomo_sessions = get("sessions", 1.0, 12.0, s.pomo_sessions as u64) as u32;
                // A phase that has not started yet picks up its new length right away.
                if s.pomo_ends == 0 {
                    s.pomo_left = s.phase_length(s.pomo_phase);
                }
            })
        }
        _ => bail!("unknown method timers.{name}"),
    }
    Ok(Value::Null)
}
