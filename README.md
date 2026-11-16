# Fableland

A desktop shell for [Hyprland](https://hyprland.org): the bar, app launcher,
notifications, lock screen, wallpapers, screenshots and settings that turn a
window manager into a desktop. It is drawn with [Quickshell](https://quickshell.org)
and run by one small program, the `fable` daemon.

> **Beta.** Fableland is young and installs on **NixOS only** for now; other
> distributions will follow. Found something broken or confusing? Please
> [open an issue](https://github.com/0perand9/fableland/issues), and see
> [Reporting a problem](#reporting-a-problem) for what to include.

## Contents

- [What you get](#what-you-get)
- [Installing on NixOS](#installing-on-nixos)
- [First steps](#first-steps)
- [Plugins](#plugins)
- [Updating](#updating)
- [Configuration](#configuration)
- [Troubleshooting](#troubleshooting)
- [Uninstalling](#uninstalling)
- [How it works](#how-it-works)
- [Contributing](#contributing)
- [Credits](#credits)

## What you get

| | |
| --- | --- |
| **Bar** | workspaces, what's playing, clock, weather, tray, keyboard layout, network, bluetooth, volume, notifications, power |
| **Launcher** | apps ranked by how often you use them, a calculator, `>` to run a command, `?` to search the web |
| **Clipboard** | searchable history of what you copied, with image previews |
| **Wallpapers** | a carousel with colour filters, video wallpapers and online search; the colours of the whole desktop follow the wallpaper |
| **Calendar** | month view, weather forecast, diary notes |
| **Music** | player controls, seeking, an equalizer (with EasyEffects) |
| **Network & volume** | Wi-Fi, Bluetooth, Ethernet; audio devices and per-app volume |
| **Control center** | notification history, do not disturb, power profiles, brightness, battery levels of mice and headsets |
| **Displays** | arrange monitors, choose resolution, refresh rate, scale, rotation and HDR |
| **Screenshots** | select a region on any monitor, then copy, edit, read the text (OCR) or scan a QR code; screen recording |
| **Focus** | how much time you spent in which apps, per day, week and month |
| **Settings** | everything, including keybinds, keyboard layouts and apps to start, applied at once |
| **Guide** | what everything does, with a cheat sheet of your keybinds |
| **Also** | notification pop-ups, volume and brightness indicators, a lock screen, idle handling, a quick panel with drawing on screen and timers, and NixOS update checks |

## Installing on NixOS

This takes a fresh-ish NixOS install to Hyprland with Fableland. It assumes
nothing beyond a working NixOS that you can log in to and a terminal. If you
already manage your system with a flake and Home Manager, skip to
[Already using flakes](#already-using-flakes-and-home-manager).

**Two words first.** A *flake* is a `flake.nix` file that pins exactly which
versions of everything your system is built from, so the same file always
gives the same system. *Home Manager* does for your user (desktop, apps,
settings) what `configuration.nix` does for the system. Fableland is installed
through both.

### 1. Turn on flakes

Open `/etc/nixos/configuration.nix` in an editor as root, for example
`sudo nano /etc/nixos/configuration.nix`, and add these two lines anywhere
between the outer `{` and `}`:

```nix
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  programs.hyprland.enable = true;
```

The first turns on flakes, the second installs Hyprland and adds it to the
login screen. In nano, save with `Ctrl+O` then `Enter`, and quit with `Ctrl+X`.
Apply it:

```sh
sudo nixos-rebuild switch
```

> **NVIDIA graphics card?** Hyprland needs the proprietary driver set up first;
> follow the [NixOS wiki page on NVIDIA](https://wiki.nixos.org/wiki/NVIDIA).

### 2. Add the three starter files

Fableland comes with a ready-made [`flake.nix`](examples/nixos/flake.nix),
[`home.nix`](examples/nixos/home.nix) and [`hyprland.lua`](examples/nixos/hyprland.lua).
Download them next to your `configuration.nix`:

```sh
cd /etc/nixos
for f in flake.nix home.nix hyprland.lua; do
  sudo curl -fLO "https://raw.githubusercontent.com/0perand9/fableland/main/examples/nixos/$f"
done
```

They are short and commented; read them. Then make two changes:

- In **`flake.nix`**, replace `alice` with your user name (run `whoami` if
  unsure): `home-manager.users.yourname = import ./home.nix;`
- In **`home.nix`**, replace `alice` with your user name in both places.

You end up with:

```
/etc/nixos/
  configuration.nix           your system (as before, plus the two lines)
  hardware-configuration.nix  your disks and hardware (untouched)
  flake.nix                   which versions to build from: NixOS, Home Manager, Fableland
  home.nix                    your user: Hyprland, Fableland, your apps
  hyprland.lua                Hyprland's settings and keybinds
```

> If `/etc/nixos` is a git repository, run `sudo git add .` there: a flake
> only sees files that git knows about.

### 3. Build it

```sh
sudo nixos-rebuild switch --flake /etc/nixos#nixos
```

The first build downloads a lot and compiles Fableland, so give it a while.
The starter `flake.nix` follows `nixos-unstable` (Hyprland 0.57, which
Fableland needs, is not in a stable release yet), so this may also update
other parts of your system. From now on, always rebuild with the
`--flake /etc/nixos#nixos` part.

If it stops with an error, the last lines say why. A typo in one of the files
is the usual reason; [Troubleshooting](#troubleshooting) has the common ones.

### 4. Log in to Hyprland

Log out. On the login screen, choose **Hyprland** as the session (usually a
menu or a gear icon near your name) and log in. The bar appears at the top
after a moment. Press **SUPER + F1** (SUPER is the Windows key) for the guide.

### Already using flakes and Home Manager

Add the input and import the module:

```nix
# flake.nix
inputs.fableland = {
  url = "github:0perand9/fableland";
  inputs.nixpkgs.follows = "nixpkgs";
};

# Home Manager configuration (pass `inputs` in through extraSpecialArgs)
imports = [ inputs.fableland.homeModules.default ];
programs.fableland.enable = true;
```

Then start the daemon from Hyprland and bind keys to it; Hyprland must be 0.57
or newer, with a Lua configuration:

```lua
hl.on("hyprland.start", function() hl.exec_cmd("systemd-cat -t fableland fable daemon") end)
hl.bind("SUPER + SPACE", hl.dsp.event("fable toggle launcher"))
```

[`examples/nixos/hyprland.lua`](examples/nixos/hyprland.lua) has a full set of
keybinds. Through `hl.dsp.event`, a keybind talks to the daemon over
Hyprland's own socket without starting a process.

## First steps

The starter keybinds:

| Keys | What it does |
| --- | --- |
| `SUPER + Return` | open a terminal (kitty) |
| `SUPER + SPACE` | the launcher: type an app's name, `Enter` |
| `SUPER + Q` | close the window |
| `SUPER + 1` … `9` | go to workspace 1 … 9; add `SHIFT` to take the window along |
| `SUPER + arrows` | move focus between windows; add `SHIFT` to move the window |
| `SUPER + F` / `SUPER + T` | fullscreen / floating window |
| `SUPER + drag` | move a window with the left button, resize with the right |
| `SUPER + F1` | the guide: what everything does, every keybind |
| `SUPER + I` | settings |
| `SUPER + N` | control center: notifications, power, brightness |
| `SUPER + V` | clipboard history |
| `SUPER + ALT + W` | wallpapers |
| `SUPER + SHIFT + M` | displays |
| `SUPER + S` | screenshot of a region; `SUPER + SHIFT + S` records the screen, again to stop |
| `SUPER + L` | lock the screen |
| `SUPER + SHIFT + E` | log out |

Most things in the bar open something when clicked. To add or change keybinds,
use **Settings → Keybinds**; those take effect at once and need no rebuild.

Things worth doing first:

- **Pick a wallpaper.** Fableland looks for them in `~/Pictures/Wallpapers`.
  Put some images there, or use the online search in the wallpaper popup. The
  desktop's colours follow the wallpaper you choose.
- **Arrange your monitors** if you have more than one (`SUPER + SHIFT + M`).
- **Install apps** by adding them to `home.packages` in `home.nix` and
  rebuilding. Search for package names at [search.nixos.org](https://search.nixos.org/packages).

The `fable` command does the same things from a terminal: `fable toggle
settings`, `fable volume +5`, `fable capture region`. `fable help` lists them.

## Plugins

Plugins add to Fableland: a popup, something in the bar, a settings page.
They are compiled in, so adding one means a rebuild. None are built in; these
exist so far:

| | |
| --- | --- |
| [**movies**](https://github.com/0perand9/fable-movies) | browse films and series, and open a title on the site of your choice |
| [**arr**](https://github.com/0perand9/fable-arr) | Sonarr and Radarr inside movies: see what's in your library, request what isn't |
| [**crypto**](https://github.com/0perand9/fable-crypto) | coin prices in the bar |
| [**wallfx**](https://github.com/0perand9/fable-wallfx) | a new wallpaper eats through the old one in pixel colonies, by Diego Malagrida |
| [**calc**](https://github.com/0perand9/fable-calc) | a calculator with a scientific mode, history and a unit and currency converter, by lukpednoi |
| [**bubble**](https://github.com/0perand9/fable-bubble) | your machine as bubbles drifting around a black hole: processes, apps, CPU, memory, by lukpednoi |

**To install one** with the starter files:

1. In `flake.nix`, uncomment the plugin's line under `inputs`, for example:
   ```nix
   fable-movies = { url = "github:0perand9/fable-movies"; flake = false; };
   ```
2. In `home.nix`, uncomment the same name in `plugins`:
   ```nix
   plugins = [
     inputs.fable-movies
   ];
   ```
3. Rebuild: `sudo nixos-rebuild switch --flake /etc/nixos#nixos`. Fableland
   restarts on its own with the plugin in it.

To remove a plugin, comment both lines out again and rebuild. A plugin you
keep can also be switched off without a rebuild, as a feature named after it
(`features.movies = false`).

Plugins have the same access to your system as Fableland itself, so only add
ones you trust. `flake.lock` pins each one, and a rebuild never brings a new
version until you [update](#updating). Each plugin's page lists its settings;
[docs/PLUGINS.md](docs/PLUGINS.md) explains how to write one and other ways to
add them (a local folder, a GitHub repository pinned by its hash).

## Updating

`flake.lock` records the exact version of everything, so nothing changes until
you ask:

```sh
cd /etc/nixos
sudo nix flake update fableland                  # just Fableland
sudo nix flake update                            # or everything: NixOS, Home Manager, plugins
sudo nixos-rebuild switch --flake /etc/nixos#nixos
```

Fableland restarts on the new version by itself after the rebuild. The
**Updates** popup tells you when the inputs of your flake have new versions.

## Configuration

Most things are set in the **Settings** popup. They are saved in
`~/.config/fableland/settings.json`.

To fix a setting from your Nix configuration instead, put it in `home.nix`:

```nix
programs.fableland.settings = {
  terminal = "kitty";
  wallpaper.dir = "~/Pictures/Wallpapers";
  workspaceCount = 10;
};
```

A setting fixed there wins, and the Settings popup shows it as set by the
system configuration; everything else stays changeable. The full list of
settings is at the end of [docs/PROTOCOL.md](docs/PROTOCOL.md).

**Features.** Parts you don't want can be switched off. A feature that is off
is gone: no buttons, no settings, and the programs only it needs are not
installed.

```nix
programs.fableland.features = {
  weather = false;
  notifications = false; # keep using mako or another notification daemon
};
```

| feature | |
| --- | --- |
| `wallpaper` | setting and browsing wallpapers |
| `palette` | desktop colours taken from the wallpaper |
| `notifications` | the notification server; off leaves notifications to another one |
| `clipboard` | clipboard history |
| `capture` | screenshots and screen recording |
| `lock` | the lock screen; off leaves locking to another locker, such as hyprlock |
| `focus` | screen-time statistics |
| `weather` | weather in the bar, the calendar and on the lock screen |
| `updates` | checking your flake's inputs for updates |
| `assistant` | the assistant |
| `quick` | the quick panel at the screen edges |

The equalizer needs EasyEffects, which is not installed for you: add
`easyeffects` to `home.packages` if you want it.

## Troubleshooting

**The build fails.** Read the last lines of the output.
- `syntax error` or `unexpected …` points at a file and line: usually a
  missing `;`, quote or bracket.
- `does not exist` / `not found` for a user: the user name in `flake.nix` or
  `home.nix` is not the one you log in with.
- `path '…' does not exist` while `/etc/nixos` is a git repository: run
  `sudo git add .` there.

**Hyprland is not on the login screen.** Check that
`programs.hyprland.enable = true;` is in `configuration.nix` and rebuild.

**Logging in gives a black screen, or Hyprland won't start.** Press
`Ctrl+Alt+F3` for a text console, log in there, and look at
`~/.local/share/hyprland/hyprland.log` or rebuild after fixing the
configuration. `Ctrl+Alt+F1` (or `F2`) goes back to the login screen. With an
NVIDIA card, check the driver first.

**No bar after logging in.** See whether the daemon runs and what it says:

```sh
fable ping                              # answers "pong" when the daemon is running
journalctl --user -t fableland -b       # its log since boot
```

`fable restart` restarts it; `fable reload` restarts only the shell.

**Something in the bar does nothing when clicked.** Run `fable reload`. If it
keeps happening, check the log above and [report it](#reporting-a-problem).

**Everything is broken after a rebuild.** NixOS keeps every previous version
of your system: restart the computer and pick an older entry in the boot
menu. Run `sudo nixos-rebuild switch --rollback` to make that the current one.

### Reporting a problem

[Open an issue](https://github.com/0perand9/fableland/issues) with what you
did, what you expected and what happened instead. Attach the log
(`journalctl --user -t fableland -b > fableland.log`) and say which graphics
card you have. A screenshot helps for anything that looks wrong; leave out
the clipboard popup, which can show passwords you copied.

## Uninstalling

Remove the `programs.fableland` block (and its `imports` line) from `home.nix`
and the `fable` lines from `hyprland.lua`, then rebuild. To leave Hyprland
too, choose your previous desktop on the login screen. Your settings and
history stay in `~/.config/fableland`, `~/.local/state/fableland` and
`~/.cache/fableland`; delete those folders to remove them as well.

## How it works

```
 Hyprland ◄──────────►┌──────────────┐          ┌─────────────────────┐
 PipeWire, UPower,    │              │  socket  │  shell/ (Quickshell)│
 NetworkManager, ───► │ fable daemon │ ◄──────► │  draws state,       │
 BlueZ, MPRIS, ...    │              │   JSON   │  sends actions      │
                      └──────────────┘          └─────────────────────┘
        keybinds, `fable <command>` ──┘
```

- **`daemon/`** is `fable`, a single Rust program that does all system work:
  Hyprland, audio, network, bluetooth, power, media players, notifications,
  wallpapers and colours, clipboard history, screen time, screenshots,
  timers, weather, updates and settings. It publishes state as *topics*,
  takes *method calls* over a Unix socket, and starts and supervises the shell.
- **`shell/`** is the Quickshell interface. It only displays what the daemon
  reports and sends actions back; it never runs a program or reads a file.
- **Plugins** are compiled into both.

Nothing polls: the daemon listens to D-Bus signals, Hyprland's event socket
and PipeWire, and pushes a topic only when it changed. Expensive data (system
statistics, Wi-Fi scans) is only produced while something on screen shows it.

## Contributing

[docs/PROTOCOL.md](docs/PROTOCOL.md) lists every topic, method, event and
setting; [docs/SHELL.md](docs/SHELL.md) explains how the interface is written;
[docs/PLUGINS.md](docs/PLUGINS.md) how plugins are.

```
daemon/       the daemon: src/modules/ has one file per area (audio.rs, net.rs, ...)
  api/        fable-plugin, what plugins are written against
shell/        the Quickshell interface
plugins/      assemble, which picks the plugins of a build; plugin checkouts go here
nix/          the package, its wrapper and the Home Manager module
dev/          tools to try changes without touching your desktop
examples/     the NixOS starter files
```

`nix develop` gives you the tools. `dev/daemon start` runs the daemon in a
sandbox that watches your session but cannot change it; `dev/window` shows the
shell in a window, fed by that daemon; `dev/shot <popup>` renders the shell in
a hidden compositor and saves a screenshot.

## Credits

- Fableland started as a heavily modified version of the Quickshell setup in
  [ilyamiro/imperative-dots](https://github.com/ilyamiro/imperative-dots). The
  look and the popups carry over; almost all code was replaced. The sounds in
  `assets/sounds/` come from it as well. Coming from that setup?
  [docs/MIGRATING.md](docs/MIGRATING.md) lists what to remove.
- The wallpaper transition of the [wallfx](https://github.com/0perand9/fable-wallfx)
  plugin is Diego Malagrida's, from
  [diegoMalagrida/pocket-dots](https://github.com/diegoMalagrida/pocket-dots)
  (GPL-3.0, which the plugin keeps).
- The [calc](https://github.com/0perand9/fable-calc) and
  [bubble](https://github.com/0perand9/fable-bubble) plugins are lukpednoi's
  calculator and Bubble monitor, from
  [lukpednoi/Anserin](https://github.com/lukpednoi/Anserin), itself a fork of
  ilyamiro's [Serpantinum](https://github.com/ilyamiro/serpantinum) (AGPL-3.0,
  which both plugins keep).
- Written by Fable (Claude), and it runs on Hyprland: hence the name.
- Built on [Quickshell](https://quickshell.org), [Hyprland](https://hyprland.org)
  and [matugen](https://github.com/InioX/matugen).
