# Fableland

A desktop shell for Hyprland: a top bar, a launcher, a control center and the
rest of what makes a desktop, drawn with [Quickshell](https://quickshell.org)
and driven by **one daemon**.

**Why "Fableland"?** It was written by Fable (Claude) and it runs on Hyprland.
That's all there is to the name.

**Where it came from.** It started as the Quickshell setup from
[ilyamiro's imperative-dots](https://github.com/ilyamiro/imperative-dots), which
I'd been running on my main machine: around 30 QML files plus about 30 shell and
Python helpers that polled the system. Fableland is a heavily modified version
of that setup. The popups and the overall look carry over, but almost all of the
code was replaced. Every helper script became part of one Rust daemon, the UI
was rewritten to only display state, and a lot of the old UI that never actually
did anything now works: the keybind editor, startup apps, keyboard layouts and
monitor layouts. Credit for the original design goes to ilyamiro. The bugs in
this version are mine.

```
 Hyprland ◄──────────►┌──────────────┐          ┌─────────────────────┐
 PipeWire, UPower,    │              │  socket  │  shell/ (Quickshell)│
 NetworkManager, ───► │ fable daemon │ ◄──────► │  draws state,       │
 BlueZ, MPRIS, ...    │              │   JSON   │  sends actions      │
                      └──────────────┘          └─────────────────────┘
        keybinds, `fable <command>` ──┘
```

* **`daemon/`** — `fable`, a single Rust program. It owns everything
  system-side: Hyprland IPC, audio, network, bluetooth, power, media players,
  notifications, wallpapers and the colour palette, clipboard history, screen
  time, screenshots and recording, timers, weather, update checks, settings. It
  publishes state as *topics* and takes *method calls* over a Unix socket, and
  it starts and supervises the shell.
* **`shell/`** — the Quickshell configuration. A pure view: it never runs a
  process, reads a file or polls anything. No helper scripts exist.

Nothing polls: the daemon listens (D-Bus signals, Hyprland's event socket,
`pactl subscribe`) and pushes a topic only when it actually changed; expensive
data (system statistics, Wi-Fi scans) is only produced while something on
screen wants it.

## What is in it

| | |
| --- | --- |
| **Bar** | workspaces, now-playing with controls, clock/date/weather, system tray, keyboard layout, network, bluetooth, volume, notifications, power, recording indicator |
| **Launcher** | applications ranked by use, calculator, `>` run a command, `?` web search |
| **Clipboard** | searchable history with text and image previews |
| **Wallpaper** | carousel with colour filters, video wallpapers, online search; the palette of the whole desktop follows the wallpaper |
| **Calendar** | month view, weather forecast, diary notes, optional schedule |
| **Music** | player control, seeking, equalizer (EasyEffects) |
| **Network** | Wi-Fi, Bluetooth, Ethernet |
| **Volume** | devices, per-application volume |
| **Control center** | notification history, do-not-disturb, session actions, power profiles, brightness, peripheral batteries |
| **Focus** | screen-time statistics per day, week, month and application |
| **Monitors** | arrange, set resolution, refresh rate, scale and rotation |
| **Settings** | everything, including keybinds, keyboard layouts and startup applications (applied live by the daemon) |
| **Guide** | what everything does, with a live cheat-sheet of your keybinds |
| **Updates** | which inputs of your NixOS flake are behind |
| **Movies** | browse a film/series catalogue and open a title on the site of your choice |
| **Quick panel** | on-screen drawing, system usage, timer / stopwatch / pomodoro |
| **Backdrops** | a moving pattern behind every popup that answers to the pointer — contour lines, a dot lattice, ripples, guilloché, Voronoi cells or soft blobs — with its strength and speed in Settings |
| **Also** | notification pop-ups, volume/brightness OSD, lock screen (PAM), screenshots with region select, edit, OCR and QR, screen recording, idle handling |

## Running it

Requirements: Hyprland and Quickshell. Optional, each enabling a feature:
`awww` or `swww` (wallpapers), `mpvpaper` + `ffmpeg` (video wallpapers),
`matugen` (palette), `pactl` (audio), `cliphist` + `wl-clipboard` (clipboard),
`grim` (screenshots), `wf-recorder` (recording), `satty` or `swappy` (edit),
`tesseract` (OCR), `zbarimg` (QR), `easyeffects` (equalizer), `xkbcli`
(keyboard layout list), `git` (update checks). NetworkManager, BlueZ, UPower
and power-profiles-daemon are used over D-Bus when present.

**With Nix**

```sh
nix run . -- daemon
```

The flake's default package is `fable` with Quickshell and the programs of its
features on its PATH; `fableland-unwrapped` is the daemon and the shell alone.
EasyEffects is not among them: install it yourself for the equalizer.
With Home Manager, use the module, which also turns features off and fixes
settings (see [Configuration](#configuration)):

```nix
# flake.nix
inputs.fableland = {
  url = "github:0perand9/fableland";
  inputs.nixpkgs.follows = "nixpkgs";
};

# home configuration
imports = [ inputs.fableland.homeModules.default ];

programs.fableland = {
  enable = true;
  features.movies = false;
  settings = {
    terminal = "kitty";
    wallpaper.dir = "~/Pictures/Wallpapers";
  };
};
```

**Without Nix**

```sh
cd daemon && cargo build --release
../dev/shaders                     # compiles the backdrop patterns; needs Qt's qsb (qtshadertools)
./target/release/fable daemon      # finds ../shell on its own when run from the source tree
```

**In Hyprland** start the daemon once and bind keys to it — see
[`examples/hyprland.lua`](examples/hyprland.lua):

```lua
hl.on("hyprland.start", function() hl.exec_cmd("fable daemon") end)
hl.bind("SUPER + SHIFT + Return", hl.dsp.event("fable toggle launcher"))
```

`fable help` lists the commands (`fable toggle <popup>`, `fable lock`,
`fable volume +5`, `fable capture region`, …). The same words work in a
terminal, in scripts and — through `hl.dsp.event("fable …")` — in keybinds,
where they do not even spawn a process.

### Coming from the old shell

The daemon replaces everything the old setup started by hand. Remove from your
Hyprland autostart: the `quickshell -p …/Shell.qml` line, `swww-daemon` and the
wallpaper restore lines, both `wl-paste --watch cliphist store` lines,
`focus_daemon.py`, `volume_listener.sh` and the start-up `matugen` call; replace
`qs_manager.sh toggle <x>` binds with `fable toggle <x>`. `playerctld` is not
needed. With hypridle, `lock_cmd = fable lock` (or drop hypridle and use
Settings → Idle). Your screen-time history and weather configuration are
imported on first start; the old files are left untouched.

## Configuration

Settings live in `~/.config/fableland/settings.json` and are edited from the
Settings popup; the file holds only what differs from the defaults and is
reloaded when you edit it by hand. State is in `~/.local/state/fableland`,
caches in `~/.cache/fableland`. The full list of settings is at the end of
[docs/PROTOCOL.md](docs/PROTOCOL.md).

**Settings fixed from outside.** A `managed.json` next to `settings.json`
holds settings a system configuration decides. They win, and the Settings
popup shows them as set by the system configuration; everything else stays
changeable. The Home Manager module writes this file from
`programs.fableland.settings` and `programs.fableland.features`, and the
running daemon picks it up when a rebuild replaces it.

**Features.** Parts you do not want can be switched off under `features`:

| | |
| --- | --- |
| `wallpaper` | setting and browsing wallpapers |
| `palette` | colours taken from the wallpaper; off, or without `wallpaper`, the built-in palette is used |
| `notifications` | the notification server; off leaves notifications to another one, such as mako |
| `clipboard` | clipboard history |
| `capture` | screenshots and screen recording |
| `lock` | the lock screen; off leaves locking to another locker, such as hyprlock |
| `focus` | screen-time statistics |
| `weather` | the weather in the bar, in the calendar and on the lock screen |
| `updates` | checking the inputs of the system flake for updates |
| `movies` | the film and series catalogue |
| `assistant` | the assistant |
| `quick` | the quick panel at the screen edges |

A feature that is off is not there: its part of the daemon does not run, its
commands are refused, the shell shows no button, popup or setting for it, and
the Nix package leaves out the programs only it needs. The daemon restarts
itself when the features change.

```json
{ "features": { "movies": false, "notifications": false } }
```

## Working on it

```
daemon/
  features.json    the features that can be switched off, with what they are
  src/
    main.rs        the Daemon struct, method routing, start-up
    hub.rs         topics and events
    ipc.rs         the socket
    settings.rs    settings.json and managed.json
    features.rs    what is switched on
    modules/       one file per area: audio.rs, net.rs, wallpaper.rs, ...
shell/             see docs/SHELL.md
docs/
  PROTOCOL.md      every topic, method, event and setting
  SHELL.md         how the UI is written, and how to try it
nix/               the package, its wrapper and the Home Manager module
dev/               sandbox daemon, the shell in a window, headless screenshots
```

Every daemon module has the same shape — `run()` publishes its topics,
`call()` answers its methods — and every part of the UI follows the handful of
rules in [docs/SHELL.md](docs/SHELL.md).

`dev/daemon start` runs the daemon in a sandbox (`.sandbox/home`) that watches
your running session but cannot change it. `dev/window` shows the shell in a
window on your desktop, fed by that daemon, to look at and click through
without replacing anything. `dev/shot <popup>` renders the shell in a private
headless compositor and saves a screenshot — it can click and type, too — so
nothing appears on your desktop at all.

## Credits

* [ilyamiro/imperative-dots](https://github.com/ilyamiro/imperative-dots), the
  Quickshell setup this one grew out of. The sounds in `assets/sounds/` come
  from it as well.
* [Quickshell](https://quickshell.org), [Hyprland](https://hyprland.org) and
  [matugen](https://github.com/InioX/matugen).
