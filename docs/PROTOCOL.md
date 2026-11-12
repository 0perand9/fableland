# The daemon protocol

`fable daemon` listens on a Unix socket (`$XDG_RUNTIME_DIR/fableland/fable.sock`,
or `$FABLE_SOCK`). Every message is one line of JSON.

```
client → daemon   {"id": 7, "m": "audio.setVolume", "p": {...}}    call a method ("id" optional)
daemon → client   {"id": 7, "ok": true, "r": ...}                   its result
                  {"id": 7, "ok": false, "err": "..."}              or its failure
                  {"t": "audio", "d": {...}}                        state of a topic
                  {"e": "toast", "d": {...}}                        one-off event
```

* **Topics** hold state. After `{"m": "sub"}` a client receives every topic once
  and then each topic again whenever it changes (never when it does not).
* **On-demand topics** cost something to produce, so the daemon only produces
  them while a client has asked: `{"m": "want", "p": {"topic": "sys"}}`, later
  `unwant`. Wants are counted per connection and released when it closes.
* **Events** are not stored; only subscribed clients see them.
* A call without `id` gets no reply; if it fails the daemon emits a `toast` event.

In QML all of this is `Daemon` (`shell/core/Daemon.qml`): `Daemon.audio`,
`Daemon.send(method, params)`, `Daemon.call(method, params, (result, error) => {})`,
`Daemon.stream(slot, method, params)` and the `Want { topic }` widget.

From a terminal: `fable watch` prints the stream, `fable get <topic>` one topic,
`fable call <method> '<json>'` calls a method.

## Topics

Values shown are examples; `…` marks more of the same.

### `hypr`
```json
{ "available": true, "active": 1, "focusedMonitor": "DP-1",
  "monitorActive": { "DP-1": 1, "DP-2": 2 },
  "workspaces": [{ "id": 1, "name": "1", "monitor": "DP-1", "windows": 6, "title": "last window title" }],
  "window": { "address": "0x…", "class": "kitty", "title": "…", "floating": false, "fullscreen": false },
  "layout": "EN", "layoutName": "English (US)", "submap": "" }
```
`window` is null on an empty workspace. Special workspaces are not listed.

### `monitors`
```json
[{ "name": "DP-1", "description": "…", "make": "…", "model": "…", "width": 3840, "height": 2160,
   "refreshRate": 59.997, "x": 0, "y": 0, "scale": 1, "transform": 0, "focused": true,
   "modes": ["3840x2160@60.00Hz", "…"] }]
```

### `audio`
```json
{ "available": true,
  "sink": { "id": 73, "name": "alsa_output.…", "description": "HyperX Cloud Flight", "volume": 80, "muted": false, "default": true, "kind": "usb" },
  "source": { … }, "sinks": [ … ], "sources": [ … ],
  "streams": [{ "id": 8228, "app": "Zen", "icon": "zen", "media": "what is playing", "volume": 95, "muted": false, "sink": 73 }] }
```
`sink`/`source` are the defaults (null without devices). `volume` is a percentage (0–150).
`kind`: `usb`, `bluetooth`, `hdmi`, `headset`, `headphone`, `speaker` or `""`.

### `power`
```json
{ "battery": { "present": false, "percent": 100, "charging": false, "state": "unknown" },
  "brightness": { "present": false, "percent": 100 },
  "peripherals": [{ "id": "gaming_input_…", "name": "Xbox Controller", "kind": "gamepad", "percent": 55, "charging": false }],
  "profile": "balanced", "profiles": ["power-saver", "balanced", "performance"],
  "host": "nixos-desktop", "user": "red", "bootTime": 1794337661 }
```
`profile` is null and `profiles` empty without power-profiles-daemon. `bootTime` is in seconds.
A present battery also has `timeToEmpty` / `timeToFull` (seconds, 0 = unknown).

### `session`
`{ "locked": false }` — the shell shows its lock screen while `locked` is true.

### `net`
```json
{ "available": true, "primary": "ethernet",
  "ethernet": { "present": true, "connected": true, "busy": false, "device": "enp5s0", "name": "Wired connection 1", "ip": "192.168.1.2", "mac": "…", "speed": 1000 },
  "wifi": { "present": true, "enabled": true, "device": "wlp4s0",
            "connected": { "ssid": "home", "signal": 52, "security": "WPA2", "frequency": 5180, "ip": "…", "ready": true },
            "networks": [{ "ssid": "home", "signal": 74, "security": "WPA2", "secure": true, "saved": true, "active": true, "frequency": 2462 }] },
  "ops": { "some ssid": "connecting" } }
```
`primary`: `ethernet`, `wifi` or `none`. `wifi.connected` is null when not connected.
`ops` maps an SSID to `connecting` or `failed` while (and shortly after) `net.wifiConnect` runs.
The network list is refreshed continuously only while the on-demand topic **`wifi`** is wanted.

### `bt`
```json
{ "present": true, "powered": true, "discovering": false,
  "connected": [ device… ],
  "devices": [{ "mac": "74:F6:…", "name": "Headset", "kind": "headset", "paired": true, "trusted": true, "rssi": null, "battery": null }],
  "ops": { "74:F6:…": "connecting" } }
```
`devices` holds everything that is not connected (paired first, then by signal).
`kind`: `headset`, `speaker`, `mouse`, `keyboard`, `gamepad`, `phone`, `computer`, `generic`.
`ops`: `connecting`, `disconnecting` or `failed`. Discovery runs only while **`btscan`** is wanted.

### `media`
```json
{ "available": true, "id": "org.mpris.MediaPlayer2.…", "name": "Mozilla zen", "desktopEntry": "zen",
  "status": "Playing", "title": "…", "artist": "…", "album": "…",
  "length": 213.0, "position": 12.5, "positionAt": 1794341796253, "rate": 1.0,
  "art": "/path/to/cover.png", "palette": ["#293836", "#…", "#…"],
  "canNext": true, "canPrev": true, "canSeek": true,
  "players": [{ "id": "…", "name": "…", "status": "Playing", "title": "…", "icon": "zen-browser" }] }
```
The active player. `position`/`length` are seconds; `position` was measured at `positionAt`
(ms since the epoch) — extrapolate while playing (`widgets/MediaClock.qml` does). `length` 0 = unknown.
`palette` holds colours taken from the cover.

### `eq`
```json
{ "available": true, "bands": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "frequencies": [31, 63, 125, 250, 500, 1000, 2000, 4000, 8000, 16000],
  "preset": "Flat", "presets": { "Flat": [ … ], "Bass": [ … ] }, "presetNames": ["Flat", "Bass", "…"], "pending": false }
```
Gains are dB (−12…12). `presetNames` gives the order to show presets in. `pending`: changes not applied yet. `available`: EasyEffects is installed.

### `theme`
```json
{ "base": "#051013", "crust": "#091518", "mantle": "#121d21", "surface0": "#162125", "surface1": "#202c2f", "surface2": "#2b373a",
  "text": "#d8e5e9", "subtext": "#bcc9cd", "dim": "#869397", "faint": "#3d494d",
  "primary": "#03d9ff", "onPrimary": "#003641", "secondary": "#a9cbe3", "tertiary": "#a6c9f6", "error": "#ffb4ab",
  "mode": "dark", "scheme": "scheme-vibrant", "generated": true, "source": "/path/to/wallpaper" }
```
Use `Theme` in QML, never this topic directly.

### `settings`
The complete settings tree — the defaults, with `settings.json` and then `managed.json` on top; see [Settings](#settings).

### `managed`
`{ "terminal": "kitty", "features": { "weather": false } }` — the settings a system configuration fixes (`managed.json`):
the same tree as `settings`, with only those keys. `settings.set` refuses them. In QML: `Daemon.fixed(path)`.

### `features`
`{ "wallpaper": true, "palette": true, "notifications": true, "clipboard": true, "capture": true, "lock": true, "focus": true,
"weather": true, "updates": true, "assistant": true, "quick": true, "movies": false }` — which [features](#features) are on,
each plugin's among them.
It does not change while the daemon runs. In QML: `Daemon.has(feature)`.

### `plugins`
`[{ "name": "movies", "title": "Movies", "icon": "…", "about": "…", "settings": { … }, "readOnly": ["…"],
"shell": { "popup": "Popup.qml", "settings": "Settings.qml", "slots": {} } }]` — the plugins of this build: their
plugin.json ([docs/PLUGINS.md](PLUGINS.md)). Those switched off are listed too; `features` says which.
A plugin publishes topics of its own, usually one named after it; the shell reads those as `Daemon.topic(name)`.

### `notif`
```json
{ "dnd": false,
  "items": [{ "id": 12, "app": "Discord", "summary": "…", "body": "…", "icon": "discord", "image": "/path.png",
              "urgency": 1, "actions": [{ "id": "default", "label": "Open" }], "timeout": 5000,
              "desktopEntry": "discord", "time": 1794341796253 }] }
```
The history, newest first (at most 100). `body` may contain simple markup. `timeout` 0 = stays.

### `capture`
`{ "recording": { "active": true, "file": "/…/Recording_….mp4", "since": 1794341796253 }, "tools": { "screenshot": true, "edit": true, "ocr": true, "qr": false, "record": true } }`

### `timers`
```json
{ "timer": { "running": false, "endsAt": 0, "remainingMs": 300000, "presetMs": 300000 },
  "stopwatch": { "running": false, "startedAt": 0, "elapsedMs": 0, "laps": [{ "total": 61000, "diff": 61000 }] },
  "pomodoro": { "running": false, "phase": "focus", "endsAt": 0, "remainingMs": 1500000, "session": 0, "sessions": 4, "workMin": 25, "shortMin": 5, "longMin": 15 } }
```
While `running`, the remaining time is `endsAt - Date.now()` (ms) and the stopwatch shows
`elapsedMs + Date.now() - startedAt`; otherwise use `remainingMs` / `elapsedMs`. `phase`: `focus`, `short`, `long`.

### `weather`
```json
{ "status": "ok", "provider": "open-meteo", "city": "Winnebago", "tempUnit": "°F", "windUnit": "mph", "updated": 1794341520,
  "current": { "condition": "clear-day", "desc": "Clear Sky", "temp": 61.0, "feels": 58.6, "humidity": 38, "wind": 11.5 },
  "days": [{ "date": "2026-11-10", "day": "Tue", "dayFull": "Tuesday", "label": "10 Nov", "condition": "clear-day", "desc": "Clear Sky",
             "min": 49.9, "max": 61.0, "feels": 58.6, "humidity": 50, "wind": 9.0, "pop": 20,
             "hourly": [{ "at": 1794344400, "hour": 15, "time": "15:00", "temp": 61.0, "condition": "clear-day" }] }] }
```
`status`: `loading`, `ok`, `error` (with `error` text) or `unconfigured`. `current` may be null.
`condition`: `clear-day`, `clear-night`, `partly-day`, `partly-night`, `cloudy`, `rain`, `storm`, `snow`, `fog`
(`Icons.weather()` / `Theme.weatherColor()`). `pop` is the chance of precipitation in percent.

### `sysinfo`
`{ "user": "red", "host": "…", "os": "NixOS 26.11", "kernel": "6.18.60", "cpu": "…", "gpu": "…", "compositor": "Hyprland 0.57.1", "avatar": "/home/red/.face", "version": "0.1.0" }`

### `wallpaper`
```json
{ "dir": "/home/red/Pictures/Wallpapers", "busy": false,
  "current": { "path": "/…/a.jpg", "image": "/…/a.jpg", "video": false, "outputs": [] },
  "items": [{ "name": "a.jpg", "path": "/…/a.jpg", "thumb": "/…/thumbs/1f.jpg", "video": false, "color": "#676f85", "bucket": "blue" }],
  "tools": { "images": true, "videos": true, "theme": true } }
```
`bucket`: `red`, `orange`, `yellow`, `green`, `blue`, `purple`, `pink`, `mono`. `thumb` appears once generated.
`busy` while thumbnails are being made. `current.image` is a still (for videos: a frame); `current` is `{}` until a wallpaper is known.

### `wallsearch`
`{ "state": "idle", "query": "", "results": [{ "id": "9f2c…", "thumb": "/…/9f2c.jpg", "url": "https://…", "width": 3840, "height": 2160, "title": "…" }] }`
— `state`: `idle`, `running`, `done`, `error`. Results arrive one by one while running.

### `apps`
`[{ "id": "kitty.desktop", "name": "kitty", "generic": "Terminal", "comment": "…", "keywords": "…", "icon": "kitty", "exec": "kitty", "terminal": false, "uses": 3, "lastUsed": 1794341520 }]`
— sorted by name. `icon` is a theme icon name or a path (`Fmt.icon()`).

### `updates`
```json
{ "supported": true, "checking": false, "count": 4, "lastCheck": 1794341562, "flakeDir": "/home/red/redos", "command": "nix flake update && …",
  "inputs": [{ "name": "nixpkgs", "url": "https://github.com/NixOS/nixpkgs", "rev": "1d06008", "latest": "f4a03c0", "lockedAt": 1793979366, "status": "behind" }] }
```
`status`: `behind`, `current` or `unknown`. `supported` is false when no flake was found. `lastCheck` 0 = not checked yet.

### `schedule`
`{ "available": false }`, or whatever the user's `schedule.command` printed plus `"available": true`. The expected shape is
`{ "title": "Classes", "link": "https://…", "events": [{ "title": "Algebra", "start": "09:00", "end": "10:30", "where": "Room 12", "note": "", "date": "2026-11-10" }] }`
(`date` optional = today; `link` optional: a page to open for the full schedule).

### `sys` (on demand)
`{ "cpu": 9, "ram": 8, "ramUsed": 10.2, "ramTotal": 125.7, "temp": 41, "rx": 1200, "tx": 300, "disk": { "used": 1.7e12, "total": 1.75e12, "percent": 97 }, "gpu": { "name": "…", "usage": 8, "temp": 41, "memUsed": 2746, "memTotal": 16303 } }`
— percentages; RAM in GiB; `rx`/`tx` bytes per second; GPU memory in MiB; `temp` in °C (may be null); `gpu` null without NVIDIA. Every 2 s.

### `focus` (on demand)
Today's `focus.stats` (below), refreshed every 3 s.

## Events

| event | data | meaning |
| --- | --- | --- |
| `ui` | `{ action: "toggle"\|"open"\|"close", target, arg }` | open/close a popup (`fable toggle launcher`) |
| `osd` | `{ kind: "volume"\|"brightness", value, muted }` | show the on-screen display |
| `toast` | `{ kind: "info"\|"success"\|"error", title, body }` | a short message from the daemon |
| `notif.new` | a notification (as in `notif.items`) | pop it up (not sent while do-not-disturb, unless critical) |
| `notif.closed` | `{ id }` | hide its pop-up |
| `capture` | `{ mode: "image", action, monitor, image, stamp }` | a frozen frame of `monitor` is at `image`: let the user select a region, then call `capture.shot` |
| `capture` | `{ mode: "record", monitor }` | let the user select a region to record, then call `capture.record` |

## Methods

Parameters in `{}`; `?` marks optional ones. Methods return null unless noted.

**ui** — `ui.toggle {target, arg?}`, `ui.open {target, arg?}`, `ui.close`, `ui.reload` (restart the shell).

**settings** — `settings.get {key}` → value, `settings.set {key, value}`, `settings.patch {patch}` (deep-merge an object), `settings.reset`.
Keys are dotted paths (`wallpaper.dir`). Changes are saved and published in `settings` immediately.
A key that `managed.json` fixes cannot be changed: `set` and `patch` fail, and `reset` leaves it as it is.

**hypr** — `hypr.workspace {id}`, `hypr.moveToWorkspace {id}` (the focused window), `hypr.nextLayout`,
`hypr.exec {command}` (run a program through Hyprland), `hypr.dispatch {lua}` (e.g. `hl.dsp.window.close()`), `hypr.eval {lua}`,
`hypr.reload`, `hypr.clients` → Hyprland's client list,
`hypr.binds` → `[{ mods: ["SUPER", "SHIFT"], key: "Return", dispatcher: "exec_cmd", action: "kitty", mouse, repeat, locked, submap }]`
(`action` is the bind's description, or what the Lua config says it does, or `""`),
`hypr.applyMonitors {monitors: [{ name, width, height, refreshRate, x, y, scale, transform }]}` (applies and remembers the layout),
`hypr.applySettings` (re-apply keybinds, keyboard layouts).

**audio** — `kind` is `sink`, `source` or `stream`; `id` a number or `"default"`.
`audio.setVolume {kind, id, value, quiet?}` (percent; `quiet` suppresses the OSD), `audio.step {kind, delta}` (default device),
`audio.setMute {kind, id, muted}`, `audio.toggleMute {kind, id}`, `audio.setDefault {kind, name}`, `audio.moveStream {id, sink}` (sink name).

**power** — `power.setBrightness {value, relative?, quiet?}`, `power.setProfile {profile}`, `power.refresh`.

**session** — `session.lock`, `session.unlock`, `session.suspend`, `session.reboot`, `session.poweroff`, `session.logout`, `session.screen {on}`.

**net** — `net.wifiSetEnabled {enabled}`, `net.wifiScan`, `net.wifiConnect {ssid, password?}` (progress in `net.ops`),
`net.wifiDisconnect`, `net.wifiForget {ssid}`, `net.ethernetSet {connected}`.

**bt** — `bt.setPowered {on}`, `bt.connect {mac}` (pairs and trusts if needed), `bt.disconnect {mac}`, `bt.remove {mac}` (forget).

**media** — `media.playPause`, `media.next`, `media.previous`, `media.seek {position}` (seconds), `media.select {id}` (make a player the active one).
All but `select` take an optional `player` id.

**eq** — `eq.setBand {index, gain}`, `eq.preset {name}`, `eq.apply`.

**notif** — `notif.dismiss {id}`, `notif.dismissApp {app}`, `notif.clear`, `notif.invoke {id, action?}` (default `"default"`),
`notif.setDnd {on}`, `notif.test {summary?, body?, app?, icon?}`.

**wallpaper** — `wallpaper.apply {path, outputs?}`, `wallpaper.cycle {direction: "next"|"prev"|"random"}`, `wallpaper.rescan`,
`wallpaper.search {query}` (results in `wallsearch`), `wallpaper.searchStop`, `wallpaper.saveResult {id, apply?}` → saved path,
`wallpaper.regenerateTheme`.

**apps** — `apps.refresh` (cheap; call when the launcher opens), `apps.launch {id}`, `apps.run {command}`.

**clipboard** — `clipboard.list {offset?, limit?, query?}` → `{ total, items: [{ id, kind: "text"|"image", text, image }] }`
(`text` is a preview; for images `image` is a file and `text` describes it), `clipboard.text {id}` → full text,
`clipboard.copy {id}`, `clipboard.copyText {text}`, `clipboard.delete {id}`, `clipboard.wipe`.

**focus** — `focus.stats {date?, app?}` →
```json
{ "date": "2026-11-10", "today": "2026-11-10", "app": null, "current": "Discord",
  "total": 25537, "yesterday": 56277, "average": 40907, "weekRange": "Nov 9 - Nov 15",
  "apps": [{ "class": "zen-beta", "name": "Zen Browser", "icon": "zen-browser", "seconds": 10795, "percent": 42.3 }],
  "weekApps": [ … ],
  "week": [{ "date": "2026-11-09", "day": "Mon", "total": 56277, "selected": false }],
  "month": [{ "date": "2026-11-01", "total": 55922, "selected": false }], "monthName": "November 2026", "monthOffset": 6,
  "halfHours": [48 numbers: seconds per half hour of the day], "heatmap": [7 days × 24 hours of seconds] }
```
Seconds everywhere. With `app` (a class) the numbers are for that application only. `monthOffset` is the weekday (0 = Monday) of the 1st.
`focus.setIdle {idle}` — the shell reports whether the user is idle (idle time is not counted).

**capture** — `capture.start {mode: "region"|"full"|"edit"|"ocr"|"qr"|"record", monitor?}` (the focused monitor unless one is named; full: shoots at once; others emit a `capture` event),
`capture.shot {x, y, w, h, viewWidth, action?}` (the selection in the overlay's coordinates and the overlay's width; `action`: `copy`, `edit`, `ocr`, `qr`),
`capture.record {x, y, w, h, monitor?, audio?}` (`audio`: `none`, `desktop`, `mic`), `capture.stop`, `capture.cancel`.

**timers** — `timers.timerSet {ms}`, `timers.timerStart`, `timers.timerPause`, `timers.timerReset`,
`timers.stopwatchStart`, `timers.stopwatchPause`, `timers.stopwatchLap`, `timers.stopwatchReset`,
`timers.pomodoroStart`, `timers.pomodoroPause`, `timers.pomodoroSkip`, `timers.pomodoroReset`, `timers.pomodoroConfig {workMin?, shortMin?, longMin?, sessions?}`.

**weather** — `weather.refresh`, `weather.geocode {name}` → `[{ name, region, country, lat, lon }]`.

**updates** — `updates.check`, `updates.run` (opens a terminal running the update command).

**Plugins** answer `<plugin>.<method>`; each plugin's README lists its methods.

**misc** — `misc.open {target}` (xdg-open a path or URL), `misc.sound {name}`, `misc.sysinfo`,
`misc.image {url}` → local path of the picture, downloaded into the cache and converted to JPEG if Qt might not read it (`RemoteImage` widget),
`misc.xkbLayouts` → `[{ id: "us(intl)", name: "English (US, intl.)" }]`, `misc.suggestDirs {prefix, limit?}` → `["/home/red/Pictures/", …]`,
`misc.diaryOpen {date?}` (`YYYY-MM-DD`; creates the note if needed), `misc.diaryDays {month: "YYYY-MM"}` → `[1, 4, 17]`.

## Settings

Stored in `~/.config/fableland/settings.json` (only what differs from the defaults). A `managed.json` beside it, with
the same keys, is read but never written: what it sets wins and cannot be changed through the daemon. It is how a system
configuration decides settings (the Home Manager module writes it). Both files are reloaded when they change.

| key | default | |
| --- | --- | --- |
| `features.<name>` | `true` | switches a [feature](#features) off |
| `uiScale` | `1.0` | multiplies the automatic UI scale |
| `workspaceCount` | `8` | workspace pills in the bar |
| `showHelpIcon`, `openGuideAtStartup` | `true`, `false` | |
| `terminal` | `"kitty"` | for terminal applications and updates |
| `osd`, `sounds` | `true`, `true` | |
| `wallpaper.dir` | `~/Pictures/Wallpapers` | |
| `wallpaper.scheme`, `wallpaper.mode` | `scheme-vibrant`, `dark` | matugen scheme and `dark`/`light` |
| `wallpaper.transition` | `random` | awww/swww transition |
| `wallpaper.themeHook` | — | command run after a new palette is generated |
| `weather.provider` | `open-meteo` | or `openweathermap` (needs `weather.owmKey`) |
| `weather.unit` | `metric` | or `imperial` |
| `weather.city`, `weather.lat`, `weather.lon`, `weather.owmCityId` | — | where |
| `keyboard.layouts`, `keyboard.options` | `[]`, `""` | xkb layouts (`"us"`, `"de(nodeadkeys)"`); empty = leave Hyprland's alone |
| `keybinds` | `[]` | `[{ keys: "SUPER + D", action: "exec"\|"fable"\|"lua", command, description, repeat, locked, enabled }]` |
| `startup` | `[]` | `[{ command, enabled }]`, run once per Hyprland session |
| `monitors` | `[]` | the saved monitor layout (written by `hypr.applyMonitors`) |
| `notifications.dnd`, `notifications.timeoutMs` | `false`, `5000` | |
| `focus.idleMinutes`, `focus.countSystem` | `5`, `false` | |
| `lock.hidePassword`, `lock.revealMs`, `lock.pamConfig` | `true`, `600`, `""` | |
| `idle.lockMinutes`, `idle.screenOffMinutes` | `0`, `0` | 0 = never |
| `capture.dir`, `capture.videoDir` | `~/Pictures/Screenshots`, `~/Videos/Recordings` | |
| `capture.editor`, `capture.audio` | `satty`, `desktop` | |
| `clipboard.autoPaste` | `false` | paste right after picking an entry |
| `diary.dir`, `diary.obsidianVault` | `~/Documents/Diary`, `""` | |
| `schedule.command` | `""` | prints the schedule JSON |
| `updates.flakeDir`, `updates.command`, `updates.intervalHours` | auto, auto, `6` | |
| `launcher.searchUrl` | DuckDuckGo | where the launcher searches the web: a link with `{query}` |
| `backdrop.style` | `contours` | what moves behind a popup: `blobs`, `lattice`, `contours`, `ripples`, `rosette`, `cells` or `none` |
| `backdrop.strength`, `backdrop.speed` | `100`, `100` | per cent of the usual visibility and pace; speed `0` stands still |
| `backdrop.reactive` | `true` | the pattern answers to the pointer |

A plugin's settings are under its name (`movies.openWith`, `arr.sonarr.url`, …), with the defaults from its plugin.json.

## Features

A feature is a part that can be left out. With `features.<name>` set to `false` its module does not run, its methods
fail (`… is switched off`), `fable toggle <name>` is refused, and the shell has no button, popup or setting for it.
They are listed in `daemon/features.json`, which the Nix module reads too:

| feature | what goes with it |
| --- | --- |
| `wallpaper` | the `wallpaper` and `wallsearch` topics, `wallpaper.*`, the wallpaper popup |
| `palette` | generating `theme` from the wallpaper (matugen); off — or without `wallpaper` — `theme` is the built-in palette |
| `notifications` | the notification server and `notif.*`; the daemon's own notifications go to whoever serves them instead |
| `clipboard` | the clipboard history: its watchers, `clipboard.*` (but `clipboard.copyText`), the clipboard popup |
| `capture` | `capture.*` and the capture overlay |
| `lock` | `session.lock`, locking before sleep and on `loginctl lock-session`, the lock screen |
| `focus` | screen-time tracking, `focus.*`, the focus popup |
| `weather` | the `weather` topic and `weather.*` |
| `updates` | the `updates` topic, `updates.*`, the updates popup |
| `assistant` | the assistant popup |
| `quick` | the quick panel |

Every plugin is a feature too, named after it: off, its task does not run, its methods are refused and the shell shows
nothing of it.

The topic of a feature that is off is not published; the shell's defaults for it (`core/Daemon.qml`) say "nothing here".
What is on is settled when the daemon starts. When `features` changes it restarts itself (once the session is not locked).

## The `fable` command

```
fable daemon [--no-shell] [--shell-dir DIR]
fable toggle|open <popup> [arg]      launcher clipboard wallpaper calendar music network volume
                                     control focus monitors settings guide updates assistant,
                                     and a plugin's popup by the plugin's name
fable toggle|open quick [draw|system|timers]      the quick panel
fable close
fable lock | logout | suspend | reboot | poweroff
fable volume|mic <+N|-N|N|mute>      fable brightness <+N|-N|N>
fable media <play-pause|next|prev>   fable workspace <N>
fable capture <region|full|edit|ocr|qr|record|stop>
fable wallpaper <next|prev|random|PATH>
fable dnd [on|off]
fable reload | restart               restart the shell | the daemon and the shell (after an update: the new build)
fable watch | get <topic> | call <method> [json]
```

Inside Hyprland the same commands run without spawning a process:
`hl.bind("SUPER + D", hl.dsp.event("fable toggle launcher"))`.
