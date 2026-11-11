import QtQuick
import qs.core
import qs.widgets

SettingsPage {
    Section {
        title: "Wallpaper"
        feature: "wallpaper"

        TextRow {
            path: "wallpaper.dir"
            label: "Folder"
            hint: "Where the wallpaper picker looks for images and videos"
            keywords: "directory path"
            directory: true
        }

        ChoiceRow {
            path: "wallpaper.transition"
            label: "Transition"
            hint: "How a new wallpaper takes the place of the old one"
            keywords: "animation awww swww"
            options: ["random", "none", "fade", "left", "right", "top", "bottom", "wipe", "grow", "center", "outer", "wave"]
        }

        ActionRow {
            label: "Wallpaper picker"
            hint: "Browse, search and apply wallpapers"
            button: "Open"
            icon: Icons.wallpaper
            onTriggered: Ui.open("wallpaper")
        }
    }

    Section {
        title: "Theme"
        feature: "palette"

        SettingRow {
            label: "Palette"
            hint: "Generated from the wallpaper"
            keywords: "theme colours colors matugen"
            focusStop: false

            Row {
                spacing: Theme.px(4)

                Repeater {
                    model: [Theme.accent, Theme.secondary, Theme.tertiary, Theme.error, Theme.surface2, Theme.surface0, Theme.base]

                    Rectangle {
                        required property color modelData

                        width: Theme.px(20)
                        height: Theme.px(20)
                        radius: width / 2
                        color: modelData
                        border.width: 1
                        border.color: Theme.border
                    }
                }
            }
        }

        ChoiceRow {
            path: "wallpaper.mode"
            label: "Mode"
            keywords: "theme dark light"
            options: ["dark", "light"]
        }

        ChoiceRow {
            path: "wallpaper.scheme"
            label: "Colour scheme"
            hint: "How matugen derives the palette from the wallpaper"
            keywords: "theme color matugen"
            options: [
                { value: "scheme-content", label: "Content" },
                { value: "scheme-expressive", label: "Expressive" },
                { value: "scheme-fidelity", label: "Fidelity" },
                { value: "scheme-fruit-salad", label: "Fruit salad" },
                { value: "scheme-monochrome", label: "Monochrome" },
                { value: "scheme-neutral", label: "Neutral" },
                { value: "scheme-rainbow", label: "Rainbow" },
                { value: "scheme-tonal-spot", label: "Tonal spot" },
                { value: "scheme-vibrant", label: "Vibrant" }
            ]
        }

        TextRow {
            path: "wallpaper.themeHook"
            label: "Theme hook"
            hint: "A command to run after a new palette is generated"
            keywords: "script command"
            placeholder: "None"
            icon: Icons.terminal
        }

        ActionRow {
            label: "Regenerate theme"
            hint: "Build the palette again from the current wallpaper"
            keywords: "theme refresh matugen"
            button: "Regenerate"
            icon: Icons.refresh
            onTriggered: Daemon.send("wallpaper.regenerateTheme")
        }
    }

    Section {
        title: "Backdrop"

        ChoiceRow {
            path: "backdrop.style"
            label: "Pattern"
            hint: "What moves behind the content of a popup"
            keywords: "background animation panel blobs lattice contours ripples rosette cells none"
            options: ["blobs", "lattice", "contours", "ripples", "rosette", "cells", "none"]
        }

        NumberRow {
            path: "backdrop.strength"
            label: "Strength"
            hint: "How visible the pattern is"
            keywords: "background opacity intensity"
            from: 20
            to: 300
            step: 10
            unit: "%"
        }

        NumberRow {
            path: "backdrop.speed"
            label: "Speed"
            hint: "How fast the pattern moves"
            keywords: "background animation pace still"
            to: 400
            step: 10
            unit: "%"
            zeroLabel: "Still"
        }

        ToggleRow {
            path: "backdrop.reactive"
            label: "Follow the pointer"
            hint: "The pattern bends, swells or ripples around the pointer"
            keywords: "background mouse reactive interactive"
        }
    }
}
