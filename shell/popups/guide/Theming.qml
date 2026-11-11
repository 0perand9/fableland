import QtQuick
import qs.core
import qs.widgets

// How the colours come about: the wallpaper feeds matugen, matugen makes the
// palette, and the palette on show here is the live one.
Item {
    id: view

    readonly property var palette: Theme.palette
    readonly property bool canGenerate: Daemon.wallpaper.tools.theme ?? false
    // "scheme-vibrant" → "vibrant"
    readonly property string scheme: (palette.scheme ?? "").replace("scheme-", "").replace(/-/g, " ")
    readonly property string status: !Daemon.has("palette") ? "That is switched off here, so the built-in palette is used."
        : !canGenerate ? "matugen is not installed, so the built-in palette is used."
        : !palette.generated ? "No palette has been generated yet; this is the built-in one."
        : "Generated as “" + scheme + "”, " + (palette.mode ?? "dark") + " mode."

    readonly property var tones: [
        { name: "base", sample: Theme.base }, { name: "crust", sample: Theme.crust }, { name: "mantle", sample: Theme.mantle },
        { name: "surface0", sample: Theme.surface0 }, { name: "surface1", sample: Theme.surface1 }, { name: "surface2", sample: Theme.surface2 },
        { name: "faint", sample: Theme.faint }, { name: "dim", sample: Theme.dim }, { name: "subtext", sample: Theme.subtext },
        { name: "text", sample: Theme.text }, { name: "accent", sample: Theme.accent }, { name: "accentText", sample: Theme.accentText },
        { name: "secondary", sample: Theme.secondary }, { name: "tertiary", sample: Theme.tertiary }, { name: "error", sample: Theme.error }
    ]
    // A taste of the palette for the diagram.
    readonly property var essence: [Theme.base, Theme.surface0, Theme.surface2, Theme.dim, Theme.text, Theme.accent, Theme.secondary, Theme.tertiary, Theme.accentText, Theme.error]
    // Hues that mean the same thing everywhere in the shell.
    readonly property var hues: [
        { name: "peach", sample: Theme.peach, note: "volume" }, { name: "blue", sample: Theme.blue, note: "network" },
        { name: "mauve", sample: Theme.mauve, note: "bluetooth" }, { name: "green", sample: Theme.green, note: "success" },
        { name: "yellow", sample: Theme.yellow, note: "warnings" }, { name: "red", sample: Theme.red, note: "errors" }
    ]

    component Stage: Column {
        property alias caption: caption.text
        default property alias content: holder.data

        spacing: Theme.px(8)

        Item {
            id: holder

            anchors.horizontalCenter: parent.horizontalCenter
            width: childrenRect.width
            height: Theme.px(92)
        }

        Txt {
            id: caption

            anchors.horizontalCenter: parent.horizontalCenter
            size: 12
            bold: true
        }
    }

    Column {
        width: parent.width
        spacing: Theme.px(16)

        PageTitle {
            width: parent.width
            title: "Colours"
            subtitle: "The wallpaper picks the palette, and the whole shell follows."
        }

        Card {
            width: parent.width
            height: Theme.px(156)

            Row {
                anchors.centerIn: parent
                spacing: Theme.px(26)

                Stage {
                    caption: "Your wallpaper"

                    RoundImage {
                        width: Theme.px(164)
                        height: Theme.px(92)
                        source: Fmt.file(Daemon.wallpaper.current.image ?? "")
                    }
                }

                Trail {
                    y: Theme.px(42)
                }

                Stage {
                    caption: "matugen"

                    Rectangle {
                        width: Theme.px(164)
                        height: Theme.px(92)
                        radius: Theme.radiusSmall
                        color: Theme.alpha(Theme.accent, 0.1)
                        border.width: 1
                        border.color: Theme.alpha(Theme.accent, 0.5)

                        Icon {
                            anchors.centerIn: parent
                            text: Icons.palette
                            size: 40
                            color: Theme.accent
                        }
                    }
                }

                Trail {
                    y: Theme.px(42)
                }

                Stage {
                    caption: "The palette"

                    Grid {
                        anchors.verticalCenter: parent.verticalCenter
                        columns: 5
                        spacing: Theme.px(6)

                        Repeater {
                            model: view.essence

                            Rectangle {
                                required property color modelData

                                width: Theme.px(28)
                                height: Theme.px(28)
                                radius: Theme.px(8)
                                color: modelData
                                border.width: 1
                                border.color: Theme.border
                            }
                        }
                    }
                }
            }
        }

        Txt {
            width: parent.width
            text: "Pick a wallpaper and fable has matugen build a palette from it, then every surface fades over to the new colours. " + view.status + " A command of your own can follow each new palette, to recolour a terminal or an editor: the theme hook in Settings (wallpaper.themeHook)."
            size: 13
            color: Theme.subtext
            wrapMode: Text.WordWrap
            lineHeight: 1.25
        }

        Row {
            spacing: Theme.px(10)

            Btn {
                visible: Daemon.has("wallpaper")
                kind: "filled"
                icon: Icons.wallpaper
                text: "Choose a wallpaper"
                onClicked: Ui.open("wallpaper")
            }

            Btn {
                icon: Icons.refresh
                text: "Regenerate the palette"
                interactive: view.canGenerate
                onClicked: Daemon.send("wallpaper.regenerateTheme")
            }
        }

        Column {
            width: parent.width
            spacing: Theme.px(10)

            Heading {
                text: "The palette right now"
            }

            Grid {
                id: toneGrid

                width: parent.width
                columns: 5
                spacing: Theme.px(10)

                Repeater {
                    model: view.tones

                    Swatch {
                        required property var modelData

                        width: (toneGrid.width - 4 * toneGrid.spacing) / 5
                        sample: modelData.sample
                        name: modelData.name
                        note: String(modelData.sample)
                    }
                }
            }
        }

        Column {
            width: parent.width
            spacing: Theme.px(10)

            Heading {
                text: "Hues that always mean the same"
            }

            Row {
                id: hueRow

                width: parent.width
                spacing: Theme.px(10)

                Repeater {
                    model: view.hues

                    Swatch {
                        required property var modelData

                        width: (hueRow.width - 5 * hueRow.spacing) / 6
                        sample: modelData.sample
                        name: modelData.note
                        note: modelData.name
                    }
                }
            }
        }
    }
}
