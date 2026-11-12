# Plugins

A plugin adds to Fableland without changing it: code that runs inside the
daemon, QML that runs inside the shell, or both. It is compiled into the
daemon, not loaded at runtime, and has the same reach as the daemon's own
modules. Nothing keeps a plugin in a box, so install the ones you trust:
read a plugin before you add it, and pin it (see [Installing](#installing)) so
that the code you read is the code you run.

None come with Fableland itself. These three live in their own repositories
and make good examples:

| plugin | what it does | shows how to |
| --- | --- | --- |
| [`movies`](https://github.com/0perand9/fable-movies) | a film and series catalogue | add a popup and a Settings page, offer a slot |
| [`arr`](https://github.com/0perand9/fable-arr) | Sonarr and Radarr in movies | fill another plugin's slot, talk to a web API |
| [`crypto`](https://github.com/0perand9/fable-crypto) | coin prices in the bar | run a task, publish a topic, add to the bar |

## What a plugin is

```
plugins/hello/
  plugin.json     what it is and what it adds to the shell
  Cargo.toml      its code, a crate named fable-hello   (optional)
  src/lib.rs
  shell/          its QML                               (optional)
    Bar.qml
  README.md
```

A plugin's name is lowercase letters and digits. It is the name of its methods
(`hello.*`), its topic, its settings (`hello.…`), its feature (`features.hello`)
and its popup (`fable toggle hello`). Names the daemon uses itself are taken.

### plugin.json

```json
{
  "name": "hello",
  "title": "Hello",
  "short": "Hi",
  "icon": "󰞅",
  "about": "One sentence: shown in the guide and in Settings.",
  "version": "1.0.0",
  "settings": { "greeting": "hello" },
  "readOnly": ["greet"],
  "shell": {
    "popup": "Popup.qml",
    "bar": "Bar.qml",
    "settings": "Settings.qml",
    "slots": { "movies.details.actions": "Button.qml" }
  }
}
```

| key | |
| --- | --- |
| `title`, `short` | its name for people; `short` where the title does not fit (the Settings rail) |
| `icon` | a glyph of the shell's icon font (JetBrainsMono Nerd Font) |
| `settings` | the defaults of its settings. They live under its name and show up in `fable get settings`; a Nix configuration can fix them like any other |
| `readOnly` | methods the development sandbox may call: those that change nothing outside the daemon |
| `shell` | files in `shell/`: a popup, something in the bar, a Settings page, and what goes in [slots](SHELL.md#plugins) |

### The code

The crate depends on `fable-plugin` and exports one function:

```toml
[package]
name = "fable-hello"
version = "1.0.0"
edition.workspace = true

[dependencies]
fable-plugin.workspace = true
```

```rust
use fable_plugin::*;

pub fn plugin() -> Plugin {
    Plugin::new()
        // Runs for the life of the daemon.
        .run(|ctx| async move {
            let mut changes = ctx.setting_changes();
            loop {
                ctx.publish(json!({ "greeting": ctx.setting_str("greeting") }));
                changes.changed().await?;
            }
        })
        // Answers hello.<method>, from the shell, `fable call` and other plugins.
        .call(|ctx, method, p| async move {
            match method.as_str() {
                "greet" => Ok(json!(format!("{}, {}", ctx.setting_str("greeting"), p.str_or("who", "you")))),
                _ => bail!("unknown method hello.{method}"),
            }
        })
}
```

`Ctx` is the plugin's handle on the daemon (`daemon/api/src/lib.rs` documents
all of it):

| | |
| --- | --- |
| `publish(data)`, `publish_to(topic, data)` | state for the shell; only a change goes out |
| `emit(event, data)`, `toast(kind, title, body)`, `notify(summary, body, icon)` | one-off events, pop-ups, desktop notifications |
| `topic(name)`, `host().lines()` | any topic's state; everything that goes out, as it goes |
| `call(method, params)` | any method of the daemon or another plugin: `ctx.call("audio.setVolume", json!({ "kind": "sink", "value": 40 }))` |
| `setting(key)`, `setting_str(key)`, `settings()`, `set_setting(key, value)`, `setting_changes()` | its own settings; `host().setting(path)` reads anyone's |
| `wanted()`, `wanted_change()` | whether the shell shows something that needs its topic, for work that costs something |
| `state_dir()`, `cache_dir()`, `open(target)`, `spawn_detached(program, args)` | files and programs |
| `read_only()`, `log(message)` | the sandbox, the daemon's log |

`fable_plugin::http` does HTTP with JSON (`http::get(url).header(k, v).json().await`),
and `fable_plugin::util` has the daemon's small helpers. A plugin can use
`tokio`, `serde`, `serde_json`, `anyhow`, `chrono`, `ureq`, `zbus` and
`futures` through `fable_plugin::*`, and no other crates from crates.io: that
way a build with your plugins in it downloads nothing new.

### The QML

The files in `shell/` are part of the shell: they import `qs.core`,
`qs.widgets`, `qs.bar`, `qs.popups.settings` and their own folder as
`qs.plugins.<name>`, and follow [SHELL.md](SHELL.md). A plugin's topic is
`Daemon.topic("hello", fallback)`; its methods are `Daemon.call("hello.greet", …)`.

- **popup**: a `PopupPage`, as in SHELL.md. It is opened by the plugin's name.
- **bar**: an item for the bar, usually a `BarGroup`.
- **settings**: a `SettingsPage` of `Section`s and rows, as the pages in `shell/popups/settings/`.
- **slots**: an item with `property var context`, which the slot fills.

A plugin can offer a slot of its own: `Slot { name: "hello.something"; context: … }`
anywhere in its QML. Name it after the plugin, and say in its README what
`context` holds.

A plugin can be QML alone (no Cargo.toml): a bar widget that shows a topic the
daemon publishes anyway, say.

## Building with plugins

`plugins/assemble` chooses the plugins of a build. It writes
`daemon/plugin-set/` (the crate that compiles their code in) and
`shell/plugins/` (their QML):

```sh
plugins/assemble                     # every plugin in plugins/
plugins/assemble hello               # just these, by name
plugins/assemble ~/src/fable-hello   # a plugin from elsewhere: copied into plugins/
plugins/assemble --none              # none (what the repository has)
cargo build
```

`plugins/` is ignored by Fableland's git (but for `assemble`), so a plugin can
live there as its own checkout: `git clone https://github.com/0perand9/fable-movies plugins/movies`.
Writing one, work in `plugins/<name>/`, run `plugins/assemble`, and try it with
`dev/daemon` and `dev/window` (SHELL.md, "Trying it"): QML reloads as you save,
and `dev/daemon build && dev/daemon restart` brings in new code.

## Installing

With the Home Manager module, list the plugins; each one is compiled in:

```nix
# flake.nix
inputs.fable-hello = { url = "github:someone/fable-hello"; flake = false; };

# home configuration
programs.fableland.plugins = [
  inputs.fable-hello                                                 # pinned by flake.lock
  { github = "someone/fable-weather2"; rev = "3f9c2e1…"; hash = "sha256-…"; }
  { src = ./my-plugins; dir = "clock"; runtimeInputs = [ pkgs.jq ]; }
  ./my-plugin
];
programs.fableland.settings.arr.sonarr = { url = "http://localhost:8989"; apiKeyFile = "/run/secrets/sonarr"; };
```

A flake input is pinned by `flake.lock`; `{ github, rev, hash }` by its hash
(leave `hash = ""` once, and the build fails with the right one). Either way a
rebuild never brings code you have not seen: updating is `nix flake update
fable-hello`, or a new `rev` and `hash`. `runtimeInputs` puts programs the
plugin runs on fable's PATH. The default is no plugins.

The package takes the same list: `fableland.override { plugins = [ … ]; }`.

A plugin that is built in can still be switched off at runtime, as the feature
named after it: `features.hello = false`.
