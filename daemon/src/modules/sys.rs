//! System statistics (`sys` topic). Sampled only while a client wants them.

use crate::{d, util};
use anyhow::Result;
use serde_json::{json, Value};
use std::time::{Duration, Instant};

/// (busy, total) jiffies across all CPUs.
fn cpu_times() -> (u64, u64) {
    let stat = std::fs::read_to_string("/proc/stat").unwrap_or_default();
    let fields: Vec<u64> = stat.lines().next().unwrap_or("").split_whitespace().skip(1).filter_map(|f| f.parse().ok()).collect();
    let total: u64 = fields.iter().take(8).sum();
    let idle = fields.get(3).copied().unwrap_or(0) + fields.get(4).copied().unwrap_or(0);
    (total.saturating_sub(idle), total)
}

/// (received, sent) bytes summed over physical-looking interfaces.
fn net_bytes() -> (u64, u64) {
    let text = std::fs::read_to_string("/proc/net/dev").unwrap_or_default();
    let (mut rx, mut tx) = (0, 0);
    for line in text.lines().skip(2) {
        let Some((name, rest)) = line.split_once(':') else { continue };
        let name = name.trim();
        if !(name.starts_with('e') || name.starts_with('w')) {
            continue;
        }
        let f: Vec<u64> = rest.split_whitespace().filter_map(|v| v.parse().ok()).collect();
        rx += f.first().copied().unwrap_or(0);
        tx += f.get(8).copied().unwrap_or(0);
    }
    (rx, tx)
}

fn meminfo() -> (f64, f64) {
    let text = std::fs::read_to_string("/proc/meminfo").unwrap_or_default();
    let field = |key: &str| text.lines().find(|l| l.starts_with(key)).and_then(|l| l.split_whitespace().nth(1)).and_then(|v| v.parse::<f64>().ok()).unwrap_or(0.0);
    let total = field("MemTotal:");
    (total - field("MemAvailable:"), total)
}

/// Path of the sysfs file holding the CPU temperature in millidegrees.
fn find_cpu_temp() -> Option<std::path::PathBuf> {
    const SENSORS: [&str; 5] = ["coretemp", "k10temp", "zenpower", "cpu_thermal", "bcm2835_thermal"];
    let hwmons: Vec<_> = std::fs::read_dir("/sys/class/hwmon").ok()?.flatten().map(|e| e.path()).collect();
    for h in &hwmons {
        let name = std::fs::read_to_string(h.join("name")).unwrap_or_default();
        if SENSORS.contains(&name.trim()) && h.join("temp1_input").exists() {
            return Some(h.join("temp1_input"));
        }
    }
    let zone = std::path::PathBuf::from("/sys/class/thermal/thermal_zone0/temp");
    zone.exists().then_some(zone)
}

fn disk_usage() -> Value {
    let Ok(path) = std::ffi::CString::new(util::home().to_string_lossy().as_bytes()) else { return Value::Null };
    let mut st: libc::statvfs = unsafe { std::mem::zeroed() };
    if unsafe { libc::statvfs(path.as_ptr(), &mut st) } != 0 {
        return Value::Null;
    }
    let total = st.f_blocks as f64 * st.f_frsize as f64;
    let free = st.f_bavail as f64 * st.f_frsize as f64;
    let used = total - free;
    json!({ "used": used, "total": total, "percent": if total > 0.0 { (used / total * 100.0).round() } else { 0.0 } })
}

async fn gpu() -> Value {
    let query = ["--query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total,name", "--format=csv,noheader,nounits"];
    let Ok(out) = util::run("nvidia-smi", &query).await else { return Value::Null };
    let f: Vec<&str> = out.lines().next().unwrap_or("").split(',').map(str::trim).collect();
    let n = |i: usize| f.get(i).and_then(|v| v.parse::<f64>().ok()).unwrap_or(0.0);
    json!({ "usage": n(0), "temp": n(1), "memUsed": n(2), "memTotal": n(3), "name": f.get(4).copied().unwrap_or("") })
}

pub async fn run() -> Result<()> {
    let hub = &d().hub;
    let temp_path = find_cpu_temp();
    let has_nvidia = util::which("nvidia-smi");
    loop {
        hub.wait_wanted("sys").await;
        let (mut cpu_prev, mut net_prev, mut at) = (cpu_times(), net_bytes(), Instant::now());
        let mut gpu_state = Value::Null;
        let mut tick = 0u32;
        // A short first interval so the tiles fill in quickly after opening.
        let mut interval = Duration::from_millis(400);
        while hub.is_wanted("sys") {
            tokio::select! {
                _ = tokio::time::sleep(interval) => {}
                _ = hub.wait_wanted_change("sys", true) => break,
            }
            interval = Duration::from_secs(2);
            let (cpu_now, net_now, now) = (cpu_times(), net_bytes(), Instant::now());
            let dt = now.duration_since(at).as_secs_f64().max(0.001);
            let cpu_total = cpu_now.1.saturating_sub(cpu_prev.1).max(1) as f64;
            let cpu = (cpu_now.0.saturating_sub(cpu_prev.0) as f64 / cpu_total * 100.0).clamp(0.0, 100.0);
            let (mem_used, mem_total) = meminfo();
            let temp = temp_path.as_ref().and_then(|p| std::fs::read_to_string(p).ok()).and_then(|t| t.trim().parse::<f64>().ok()).map(|t| (t / 1000.0).round());
            // nvidia-smi is comparatively slow, so it is sampled at a third of the rate.
            if has_nvidia && tick % 3 == 0 {
                gpu_state = gpu().await;
            }
            tick += 1;
            hub.publish(
                "sys",
                &json!({
                    "cpu": cpu.round(),
                    "ram": if mem_total > 0.0 { (mem_used / mem_total * 100.0).round() } else { 0.0 },
                    "ramUsed": mem_used / 1048576.0,
                    "ramTotal": mem_total / 1048576.0,
                    "temp": temp,
                    "rx": (net_now.0.saturating_sub(net_prev.0) as f64 / dt).round(),
                    "tx": (net_now.1.saturating_sub(net_prev.1) as f64 / dt).round(),
                    "disk": disk_usage(),
                    "gpu": gpu_state,
                }),
            );
            (cpu_prev, net_prev, at) = (cpu_now, net_now, now);
        }
    }
}
