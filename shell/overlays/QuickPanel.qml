import QtQuick
import Quickshell
import qs.overlays.quick

// The quick-actions panel. Resting the pointer on the left, right or bottom
// edge of a screen brings out a handle there; the handle expands into a strip
// of actions — draw on the screen, system usage, timers.
// Keybinds reach it too: `fable toggle quick [draw|system|timers]`.
Scope {
    Variants {
        model: Quickshell.screens

        Dock {}
    }
}
