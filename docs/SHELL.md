# Writing the shell

The shell (`shell/`) is a Quickshell configuration and nothing but a view: it
draws what the daemon publishes and sends the user's actions back. It never
runs processes, reads files or polls anything itself.

```
shell/
  shell.qml            what exists: bars, the popup host, overlays
  core/                singletons
    Daemon.qml           the socket to the daemon: topics, events, calls
    Theme.qml            colours, fonts, sizes, motion
    Ui.qml               which popup is open
    Icons.qml            icon glyphs by name
    Fmt.qml              formatting helpers (durations, sizes, icon and file URLs)
    Pictures.qml         pictures from the web, fetched and cached by the daemon
  widgets/             building blocks shared by everything
  bar/                 the top bar
  popups/              PopupHost.qml and one file per popup (popups/<Name>.qml)
  overlays/            toasts, OSD, lock screen, capture overlay, quick panel
```

Import what you need: `import qs.core`, `import qs.widgets`. A popup that grows
past a few hundred lines splits into `popups/<name>/Part.qml` (`import qs.popups.<name>`).

## Rules

1. **State comes from `Daemon`, actions go to `Daemon`.** Bind to topics
   (`Daemon.audio.sink.volume`), call methods (`Daemon.send("audio.toggleMute", {...})`).
   Topics, methods and events are listed in [PROTOCOL.md](PROTOCOL.md). If the
   daemon does not offer something, it gets added to the daemon — never worked
   around with `Process`, `FileView` or timers that poll.
2. **Show the truth.** Controls display daemon state; a click sends a request and
   the display changes when the daemon reports the change. (`Slide` covers the
   time in between for sliders.) Do not keep a second copy of state in the view.
3. **Sizes are design units.** The UI is designed for a 1920x1080 screen and scaled
   by `Theme.px()`: write `width: Theme.px(240)`, never `width: 240`. Exceptions:
   hairlines (`border.width: 1`) and the `size` property of `Txt`/`Icon`/`IconBtn`/
   `AppIcon`, which already is in design units. Do not hardcode screen sizes.
4. **Colours come from `Theme`.** No colour literals. Translucency: `Theme.alpha(Theme.surface0, 0.6)`.
5. **Text is `Txt`, glyphs are `Icon` + `Icons`.** If a glyph is missing, add it to `Icons.qml`.
6. **Lists that update use `KeyedModel`** so delegates (and their hover, drag and
   animation state) survive updates. A plain JS array is the right model for data
   that is fetched once, and for a list that is re-ranked as a whole on every
   change (the launcher's results): there nothing would survive anyway.
7. **Expensive topics are wanted, not assumed:** `Want { topic: "sys" }`.
8. **Animations stop when nobody is looking** (`running: visible && ...`).
   Nothing may animate forever in a hidden item.
9. **A feature that is off is not there.** Whatever belongs to a feature
   ([PROTOCOL.md](PROTOCOL.md#features)) asks `Daemon.has("weather")` and, when
   that is false, shows nothing: no button, no empty panel, no call to the
   daemon — which would only come back as an error. Lists of things to offer
   (the tour, the command references, the pages of the settings) give their
   entries a `feature` and filter on it.

QML traps that have bitten this code before:

- A property named `on<Capital>…` (say `onToday`) is taken for a signal handler
  and silently never evaluates.
- A `WheelHandler` only hears mouse wheels unless it says
  `acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad`.
- Children of a `ClippingRectangle` (and so of `RoundImage`) live in its content
  item: `parent` is not the rectangle. Refer to it by id.
- Items declared inside a `List`/`ListView` land on the view, not among the
  rows; give them `parent: list.contentItem` to scroll along.
- In an `on<Property>Changed` handler, bindings derived from that property may
  still hold their old value. Read the property that changed.
- A singleton with more than a dozen `Behavior`s crashes Qt 6.12 at start-up
  (which is why `Theme` fades its palette with one factor).
- An animation does not replace a binding. A property bound to its starting
  value (`y: -Theme.px(16)`) and then animated away snaps back the moment the
  binding re-evaluates — when the scale changes, say. Leave the property
  unbound and give the start as the animation's `from`.
- Glyphs of an icon font overhang their cell, so a centred `Text` is not a
  centred picture. `Icon` centres by ink; draw glyphs with it, never with `Text`.

## Theme

Backgrounds, darkest first: `base`, `crust`, `mantle`. Raised surfaces: `surface0`,
`surface1`, `surface2`. Text: `text`, `subtext`, `dim`, `faint`. Accent: `accent`
with `accentText` for content on top of it; `secondary`, `tertiary`, `error`.
`border` is the standard hairline colour.

Hues with a fixed meaning — keep these associations everywhere:

| hue | used for |
| --- | --- |
| `Theme.blue` | network, the clock |
| `Theme.mauve` | bluetooth, microphones/inputs |
| `Theme.peach` | volume/outputs, temperature |
| `Theme.green` | success, charging, updates |
| `Theme.yellow` | warnings, brightness, notifications |
| `Theme.red` | destructive actions, errors, recording |
| `Theme.teal`, `Theme.sapphire`, `Theme.pink` | extra series in charts |

Shape: `Theme.radiusLarge` (popups), `Theme.radius` (cards), `Theme.radiusSmall`
(rows, buttons, fields); spacing `Theme.gap` (8) and `Theme.pad` (16).
Type scale (design units): 10–11 captions, 12–13 body, 14–16 emphasis, 20+ display.
Motion: `Theme.fast` (120 ms, hover), `Theme.normal` (220 ms, state changes),
`Theme.slow` (400 ms, entrances); ease out (`Easing.OutCubic`), `OutBack` for a playful pop.

## Widgets

| widget | what it is |
| --- | --- |
| `Txt`, `Icon`, `AppIcon` | text, a glyph, an application/theme icon (glyph fallback) |
| `Card` | raised surface grouping related controls |
| `Clickable` | surface with hover/press feedback and `clicked` — base of buttons and rows |
| `Btn`, `IconBtn` | text button (`kind`: filled, tonal, flat), icon button |
| `HoldBtn` | must be held until its liquid fills — for destructive actions |
| `Toggle`, `Slide`, `Tabs`, `Field` | switch, slider, segmented control, text field |
| `Stretch` | the travelling selection pill (fast leading edge, slow trailing edge) |
| `Orb`, `Wave`, `Ring`, `Spinner` | liquid gauge, liquid fill, circular gauge, busy indicator |
| `Backdrop` | what moves behind a popup's content: the user's pattern, in the popup's colours |
| `Marquee` | text that scrolls when it does not fit |
| `RoundImage`, `RemoteImage` | image cropped into a rounded box, from a file (`source: Fmt.file(path)`) or the web (`url`) |
| `SearchBar`, `KeyHints` | the big search field of list popups, and the row of key hints below them |
| `List`, `Scroll`, `Scroller` | list view, scroll area, scroll indicator |
| `KeyedModel`, `Want`, `MediaClock` | stable models from topic arrays, on-demand topics, playback position |
| `PopupPage` | the root of a popup |

`Toggle`, `Tabs` and `Slide` never change themselves: bind their value to state
and change the state in their signal handler.

The look: dark translucent surfaces, hairline borders, generous radii, one accent,
a moving `Backdrop` for atmosphere, and the *stretchy* highlight (`Stretch`, `Tabs`) wherever a
selection moves. Liquid (`Orb`, `Wave`, `HoldBtn`) for levels and for confirmation.

## Popups

A popup is `popups/<Name>.qml` with a `PopupPage` root, listed in `Ui.popups`.
A popup that is a feature has the feature's name, which takes it off that list
while the feature is off.

```qml
import QtQuick
import qs.core
import qs.widgets

PopupPage {
    implicitWidth: Theme.px(450)       // the host's frame follows these (animated)
    implicitHeight: Theme.px(700)
    placement: "top-right"             // center | top | top-left | top-right | bottom | left | right | wide
    // `arg` holds the argument of `fable toggle <popup> <arg>`
}
```

The host (`PopupHost.qml`) provides the frame (background, border, shadow, rounded
clipping), the open/close/morph animations, Escape and click-outside. The page
only fills it. Keyboard focus is inside the page: give `focus: true` to the item
that should type first. Close with `Ui.close()`, open another with `Ui.open(name, arg)`.
A failed call the user should know about becomes a toast: `Daemon.toast("error", title, text)`.

`popups/Volume.qml` is the reference: read it before writing a popup.

An overlay that opens on command (the quick panel) is named in `Ui.overlays`
instead. `Ui.open`/`Ui.toggle` — and so `fable toggle quick` — reach it through
the `Ui.overlay(name, action, arg)` signal; how it shows itself is its own business.

## Backdrops

A popup puts `Backdrop { anchors.fill: parent; colors: [...] }` behind its
content and says no more than its colours. Which pattern that draws, how strong
and how fast, is the user's setting (`backdrop.*`, Settings → Appearance).

`blobs` is QML (`Blobs.qml`). Every other pattern is a fragment shader,
`widgets/backdrop/<style>.frag`, which is told the time, the popup's colours
and where the pointer is. `backdrop/common.glsl` lists what a pattern is given
and holds the helpers they share (`here()`, `nearness()`, `stroke()`, `paint()`).
A new pattern is one `.frag` file plus its name among the options in
`popups/settings/AppearancePage.qml`. Keep it quiet: text sits on top of it.

Qt only loads shaders compiled to `.qsb`, and those are not in git. `dev/window`
and `dev/shot` compile whatever is stale, the flake compiles them when it
builds, and `dev/shaders` does it by hand.

## Trying it

```
dev/daemon start          the daemon in a sandbox (.sandbox/home), read-only towards your session
dev/window                the shell in a window on your desktop (dev/window network:bt opens a popup)
dev/shot                  render the bar headlessly → .sandbox/shots/bar.png
dev/shot network:bt       ... with a popup open (and its argument)
dev/shot -s 3840x2160 -w 4 -c 0,0,1200,900 -o /tmp/x.png calendar
dev/fable get audio       ask the sandbox daemon (also: watch, call <method> '<json>')
dev/shaders               compile the backdrop patterns (the two above do it themselves)
```

`dev/window` runs the shell inside a nested compositor: one window holding the
bar, popups and overlays, reloading as you edit. The sandbox daemon refuses
whatever would change your session, so controls that do (volume, Wi-Fi, ...)
answer with an error toast there. Your keybinds stay with your real session;
open popups by clicking the bar or with `dev/fable toggle <popup>`.
A reload starts with the first file that changes and can miss one saved right
after it: if the window shows half of a change, save again.
`dev/fable lock` locks that window and nothing else: the shell locks the
compositor it runs in, and the sandbox daemon takes no notice of your real
session locking.

One thing in that window is not the shell's doing: under Hyprland the first
wheel notch after a change of direction still goes the old way. Hyprland sends
a scroll's distance before its step count; the nested compositor expects the
opposite and pairs each distance with the previous step. The shell on Hyprland
itself gets the events first-hand and is not affected.

`dev/shot` starts a private headless compositor, so nothing shows up on your
desktop; it prints the warnings and errors the shell logged. Overlays that
normally need a trigger have previews: `dev/shot lock`, `dev/shot capture`,
`dev/shot quick` (and the same with `dev/window`).

To run the real thing: `fable daemon` (it starts and supervises Quickshell itself).
