pragma Singleton
import QtQuick
import Quickshell

// Which popup is open, and where. The popup host (popups/PopupHost.qml) renders
// whatever this says; the bar, keybinds (`fable toggle <popup>`) and popups
// themselves change it through open/toggle/close.
Singleton {
    id: root

    // Every popup has a file popups/<Name>.qml with the first letter capitalised.
    // One that is a feature (Daemon.has) carries the feature's name, and is not here while that is off.
    readonly property var popups: ["launcher", "clipboard", "wallpaper", "calendar", "music", "network", "volume", "control", "focus", "monitors", "settings", "guide", "updates", "movies", "assistant"].filter(name => Daemon.has(name))
    // Overlays that open and toggle like popups but look after themselves:
    // each listens for `overlay` with its own name.
    readonly property var overlays: ["quick"].filter(name => Daemon.has(name))

    property string current: ""
    // Optional argument, e.g. the tab to show ("network" takes "wifi" or "bt").
    property string arg: ""
    // The screen the popup is shown on.
    property var screen: null

    // Development aid: what FABLE_DEV_OPEN asks to show at start-up — a popup
    // ("network:bt") or an overlay preview ("lock", "capture", "quick"). See dev/shot.
    readonly property string dev: Quickshell.env("FABLE_DEV_OPEN") || ""

    // The lock screen is up. The lock itself (overlays/Lock.qml) has the last word:
    // it stays up when the daemon restarts and forgets, until a password opens it.
    readonly property bool locked: Daemon.session.locked || lockHeld
    property bool lockHeld: false
    readonly property var focusedScreen: screenNamed(Daemon.hypr.focusedMonitor)

    function screenNamed(name) {
        for (const s of Quickshell.screens)
            if (s.name === name)
                return s;
        return Quickshell.screens[0] ?? null;
    }

    // `action` is "open" or "toggle"; the overlay on the focused screen answers.
    signal overlay(string name, string action, string arg)

    function open(name, arg, screen) {
        if (overlays.indexOf(name) >= 0) {
            if (!locked)
                overlay(name, "open", arg ?? "");
            return;
        }
        if (popups.indexOf(name) < 0) {
            console.warn("fable: no popup named", name);
            return;
        }
        if (locked)
            return;
        root.screen = screen ?? focusedScreen;
        root.arg = arg ?? "";
        root.current = name;
    }

    // Opening the popup that is already open closes it — unless a different
    // argument is given, which switches it (wifi → bt) instead.
    function toggle(name, arg, screen) {
        if (overlays.indexOf(name) >= 0) {
            if (!locked)
                overlay(name, "toggle", arg ?? "");
            return;
        }
        const sameArg = !arg || arg === root.arg;
        const sameScreen = !screen || screen === root.screen;
        if (current === name && sameArg && sameScreen)
            close();
        else
            open(name, arg, screen);
    }

    function close() {
        root.current = "";
    }

    function fileFor(name) {
        return Qt.resolvedUrl("../popups/" + name.charAt(0).toUpperCase() + name.slice(1) + ".qml");
    }

    onLockedChanged: if (locked) close()

    Connections {
        target: Daemon
        enabled: root.dev !== ""

        function onReadyChanged() {
            const [name, arg] = root.dev.split(":");
            if (Daemon.ready && root.popups.indexOf(name) >= 0)
                root.open(name, arg);
        }
    }

    Connections {
        target: Daemon

        function onEvent(name, data) {
            if (name !== "ui")
                return;
            if (data.action === "close")
                root.close();
            else if (data.action === "open")
                root.open(data.target, data.arg);
            else if (data.action === "toggle")
                root.toggle(data.target, data.arg);
        }
    }
}
