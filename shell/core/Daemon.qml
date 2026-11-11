pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The shell's only link to the outside world: a line-delimited JSON socket to
// the `fable` daemon (see docs/PROTOCOL.md).
//
//   state    Daemon.audio.sink.volume          one property per topic, replaced when it changes
//   events   Connections { target: Daemon; function onEvent(name, data) {} }
//   calls    Daemon.send("audio.setVolume", { kind: "sink", id: "default", value: 40 })
//            Daemon.stream("volume", "audio.setVolume", {...})   (rate-limited, for sliders)
//            Daemon.call("clipboard.list", { limit: 50 }, (result, error) => {})
//   on-demand topics   Want { topic: "sys" }   (widgets/Want.qml)
//   features           Daemon.has("weather")   false for a part that is switched off
//   plugins' topics    Daemon.topic("crypto", fallback)
Singleton {
    id: root

    readonly property bool connected: socket.connected
    // True once the first full snapshot of topics has arrived.
    property bool ready: false

    // ── topics ───────────────────────────────────────────────────────────
    // The defaults mirror the shape the daemon publishes so bindings are safe before it connects.
    property var hypr: ({ available: false, active: 1, focusedMonitor: "", layout: "", layoutName: "", monitorActive: ({}), submap: "", window: null, workspaces: [] })
    property var monitors: []
    property var audio: ({ available: false, sink: null, source: null, sinks: [], sources: [], streams: [] })
    property var power: ({ battery: { present: false, percent: 100, charging: false, state: "unknown" }, brightness: { present: false, percent: 100 }, peripherals: [], profile: null, profiles: [], host: "", user: "", bootTime: 0 })
    property var session: ({ locked: false })
    property var net: ({ available: false, primary: "none", ethernet: { present: false, connected: false, busy: false }, wifi: { present: false, enabled: false, connected: null, networks: [] }, ops: ({}) })
    property var bt: ({ present: false, powered: false, discovering: false, devices: [], connected: [], ops: ({}) })
    property var media: ({ available: false, players: [], status: "Stopped", title: "", artist: "", album: "", length: 0, position: 0, positionAt: 0, rate: 1, art: "", palette: [], canNext: false, canPrev: false, canSeek: false })
    property var eq: ({ available: false, bands: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0], frequencies: [], preset: "Flat", presets: ({}), presetNames: [], pending: false })
    property var theme: null
    property var settings: ({})
    // The settings a system configuration fixes (managed.json): the same tree, with only those keys.
    property var managed: ({})
    // Which parts of the shell are on, by name; see has().
    property var features: ({})
    // The plugins of this build: their plugin.json (see docs/PLUGINS.md and core/Plugins.qml).
    property var plugins: []
    // Topics the shell has no property for — the plugins' — by name; see topic().
    property var others: ({})
    property var notif: ({ dnd: false, items: [] })
    property var capture: ({ recording: { active: false }, tools: ({}) })
    property var timers: ({
            timer: { running: false, endsAt: 0, remainingMs: 300000, presetMs: 300000 },
            stopwatch: { running: false, startedAt: 0, elapsedMs: 0, laps: [] },
            pomodoro: { running: false, phase: "focus", endsAt: 0, remainingMs: 1500000, session: 0, sessions: 4, workMin: 25, shortMin: 5, longMin: 15 }
        })
    property var weather: ({ status: "loading", city: "", current: null, days: [], tempUnit: "°C", windUnit: "km/h" })
    property var sysinfo: ({})
    property var wallpaper: ({ busy: false, current: ({}), dir: "", items: [], tools: ({}) })
    property var wallsearch: ({ state: "idle", query: "", results: [] })
    property var apps: []
    property var updates: ({ supported: false, checking: false, count: 0, inputs: [] })
    property var schedule: ({ available: false })
    // On-demand topics: null until something wants them (see Want).
    property var sys: null
    property var focus: null

    // One-off events: "ui", "osd", "toast", "notif.new", "notif.closed", "capture".
    signal event(string name, var data)

    // ── calls ────────────────────────────────────────────────────────────

    // Fire and forget. Failures come back as a "toast" event.
    function send(method, params) {
        write({ m: method, p: params ?? {} });
    }

    // Call with a reply: done(result, error) — exactly one of the two is set.
    function call(method, params, done) {
        if (!socket.connected) {
            if (done)
                done(undefined, "not connected to the daemon");
            return;
        }
        const id = ++internal.lastId;
        internal.pending[id] = done;
        write({ id: id, m: method, p: params ?? {} });
    }

    // Show a message as a pop-up, as the daemon does with its own "toast" events.
    // For failures of call(), which — unlike send() — the daemon leaves to the caller.
    function toast(kind, title, body) {
        root.event("toast", { kind: kind, title: title, body: body ?? "" });
    }

    // send() for values that change continuously (a slider being dragged): calls
    // sharing a `slot` go out at most every 40 ms, and the last one always does.
    function stream(slot, method, params) {
        if (slot in internal.streams) {
            internal.streams[slot] = { m: method, p: params };
            return;
        }
        internal.streams[slot] = null;
        send(method, params);
        streamTimer.start();
    }

    // The value of a setting by dotted path, e.g. setting("wallpaper.dir", "").
    function setting(path, fallback) {
        let v = root.settings;
        for (const key of path.split(".")) {
            if (v === null || typeof v !== "object" || !(key in v))
                return fallback;
            v = v[key];
        }
        return v ?? fallback;
    }

    function setSetting(path, value) {
        send("settings.set", { key: path, value: value });
    }

    // Whether the system configuration fixes the setting at `path`, so that it cannot be changed here.
    function fixed(path) {
        let v = root.managed;
        for (const key of path.split(".")) {
            if (v === null || typeof v !== "object" || Array.isArray(v))
                break;
            if (!(key in v))
                return false;
            v = v[key];
        }
        // An object only fixes some of what is inside it.
        return v === null || typeof v !== "object" || Array.isArray(v);
    }

    // The state of a topic without a property of its own, such as a plugin's.
    function topic(name, fallback) {
        return root.others[name] ?? fallback;
    }

    // Whether a feature is on (docs/PROTOCOL.md lists them). What is off does not
    // exist: no popup, no button, no call to the daemon.
    function has(feature) {
        return root.features[feature] !== false;
    }

    // Ask the daemon to produce an on-demand topic. Calls are counted; prefer the Want widget.
    function want(topic) {
        const n = (internal.wants[topic] ?? 0) + 1;
        internal.wants[topic] = n;
        if (n === 1)
            write({ m: "want", p: { topic: topic } });
    }

    function unwant(topic) {
        const n = (internal.wants[topic] ?? 0) - 1;
        if (n > 0) {
            internal.wants[topic] = n;
            return;
        }
        delete internal.wants[topic];
        write({ m: "unwant", p: { topic: topic } });
    }

    // ── plumbing ─────────────────────────────────────────────────────────

    function write(message) {
        if (!socket.connected)
            return;
        socket.write(JSON.stringify(message) + "\n");
        socket.flush();
    }

    function handle(line) {
        let msg;
        try {
            msg = JSON.parse(line);
        } catch (e) {
            console.warn("fable: unreadable message from the daemon:", e);
            return;
        }
        if (msg.t !== undefined) {
            if (internal.topics.has(msg.t)) {
                root[msg.t] = msg.d;
            } else {
                const others = Object.assign({}, root.others);
                others[msg.t] = msg.d;
                root.others = others;
            }
        } else if (msg.e !== undefined) {
            root.event(msg.e, msg.d);
        } else if (msg.id === 0) {
            root.ready = true;
        } else if (msg.id !== undefined) {
            const done = internal.pending[msg.id];
            delete internal.pending[msg.id];
            if (done)
                done(msg.ok ? msg.r : undefined, msg.ok ? null : (msg.err ?? "failed"));
        }
    }

    QtObject {
        id: internal

        readonly property var topics: new Set(["hypr", "monitors", "audio", "power", "session", "net", "bt", "media", "eq", "theme", "settings", "managed", "features", "plugins", "notif", "capture", "timers", "weather", "sysinfo", "wallpaper", "wallsearch", "apps", "updates", "schedule", "sys", "focus"])
        property int lastId: 0
        property var pending: ({})
        property var wants: ({})
        property var streams: ({})
    }

    Timer {
        id: streamTimer

        interval: 40
        repeat: true
        onTriggered: {
            let busy = false;
            for (const slot in internal.streams) {
                const next = internal.streams[slot];
                if (next) {
                    root.send(next.m, next.p);
                    internal.streams[slot] = null;
                    busy = true;
                } else {
                    delete internal.streams[slot];
                }
            }
            if (!busy)
                stop();
        }
    }

    Socket {
        id: socket

        path: Quickshell.env("FABLE_SOCK") || (Quickshell.env("XDG_RUNTIME_DIR") + "/fableland/fable.sock")
        connected: true
        parser: SplitParser {
            onRead: line => root.handle(line)
        }
        onConnectedChanged: {
            if (connected) {
                // Subscribe (the reply to id 0 marks the end of the snapshot) and restore on-demand topics.
                root.write({ id: 0, m: "sub" });
                for (const topic in internal.wants)
                    root.write({ m: "want", p: { topic: topic } });
            } else {
                for (const id in internal.pending) {
                    const done = internal.pending[id];
                    if (done)
                        done(undefined, "connection to the daemon was lost");
                }
                internal.pending = ({});
            }
        }
    }

    // The daemon may start after the shell, or restart underneath it.
    Timer {
        interval: 1000
        repeat: true
        running: !socket.connected
        onTriggered: socket.connected = true
    }
}
