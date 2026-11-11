//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1

import QtQuick
import Quickshell
import qs.core
import qs.bar
import qs.popups
import qs.overlays
import qs.plugins // so that Quickshell knows the plugins' QML (plugins/Index.qml)

// Fableland's view layer. Everything here only draws state published by the
// `fable` daemon and sends the user's actions back to it (core/Daemon.qml).
ShellRoot {
    // Editing a file reloads the shell — except in dev/shot runs, where a
    // reload in the middle of a scripted interaction would spoil it.
    Component.onCompleted: Quickshell.watchFiles = !Quickshell.env("FABLE_NO_RELOAD")

    // A bar on every screen.
    Variants {
        model: Quickshell.screens

        Bar {}
    }

    // Launcher, control center, calendar, ... — one at a time, in one morphing frame.
    PopupHost {}

    Toasts {}
    Osd {}

    // The handles at the screen edges, and what they bring out.
    LazyLoader {
        active: Daemon.has("quick")

        QuickPanel {}
    }

    // Region selection for screenshots and recordings.
    LazyLoader {
        active: Daemon.has("capture")

        Capture {}
    }

    // A lock screen that is up stays up, whatever becomes of the feature.
    LazyLoader {
        active: Daemon.has("lock") || Ui.lockHeld

        Lock {}
    }

    // Tells the daemon when nobody has touched the machine for a while.
    Idle {}
}
