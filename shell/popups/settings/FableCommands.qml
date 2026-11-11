import QtQuick
import qs.core

// What a keybind with the "fable" action can run: the vocabulary of the `fable`
// command (docs/PROTOCOL.md), each command with what it does. The numbers in
// "volume +5" or "workspace 1" are examples to edit. A command of a feature
// (Daemon.has) names it, and is left out while that is off.
QtObject {
    readonly property var all: Ui.popups.map(popup => ({ command: "toggle " + popup, about: "Open or close " + popup })).concat([
        { command: "close", about: "Close the open popup" },
        { command: "lock", about: "Lock the session", feature: "lock" },
        { command: "suspend", about: "Suspend the computer" },
        { command: "logout", about: "Log out" },
        { command: "reboot", about: "Restart the computer" },
        { command: "poweroff", about: "Power off" },
        { command: "volume +5", about: "Volume up" },
        { command: "volume -5", about: "Volume down" },
        { command: "volume mute", about: "Mute or unmute the output" },
        { command: "mic mute", about: "Mute or unmute the microphone" },
        { command: "brightness +5", about: "Brighter screen" },
        { command: "brightness -5", about: "Dimmer screen" },
        { command: "media play-pause", about: "Play or pause" },
        { command: "media next", about: "Next track" },
        { command: "media prev", about: "Previous track" },
        { command: "workspace 1", about: "Go to a workspace" },
        { command: "capture region", about: "Screenshot of a region", feature: "capture" },
        { command: "capture full", about: "Screenshot of the screen", feature: "capture" },
        { command: "capture edit", about: "Screenshot, then annotate", feature: "capture" },
        { command: "capture ocr", about: "Copy text from the screen", feature: "capture" },
        { command: "capture qr", about: "Read a QR code", feature: "capture" },
        { command: "capture record", about: "Record a region", feature: "capture" },
        { command: "capture stop", about: "Stop recording", feature: "capture" },
        { command: "wallpaper next", about: "Next wallpaper", feature: "wallpaper" },
        { command: "wallpaper prev", about: "Previous wallpaper", feature: "wallpaper" },
        { command: "wallpaper random", about: "Random wallpaper", feature: "wallpaper" },
        { command: "dnd", about: "Do not disturb on or off", feature: "notifications" },
        { command: "reload", about: "Restart the shell" }
    ]).filter(entry => Daemon.has(entry.feature ?? ""))
}
