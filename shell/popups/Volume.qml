import QtQuick
import qs.core
import qs.widgets

// The mixer: output devices, input devices and per-application volume.
// The orb and big slider control the default device of the selected tab.
PopupPage {
    id: page

    // 0 outputs · 1 inputs · 2 applications; `fable toggle volume inputs|apps` picks one.
    property int tab: arg === "inputs" ? 1 : arg === "apps" ? 2 : 0
    readonly property var audio: Daemon.audio
    readonly property bool inputs: tab === 1
    readonly property string kind: inputs ? "source" : "sink"
    readonly property var master: inputs ? audio.source : audio.sink
    readonly property color hue: inputs ? Theme.mauve : Theme.peach

    function setVolume(kind, id, percent) {
        Daemon.stream("volume-" + kind + id, "audio.setVolume", { kind: kind, id: id, value: Math.round(percent), quiet: true });
    }

    implicitWidth: Theme.px(450)
    implicitHeight: Theme.px(700)
    placement: "top-right"

    Backdrop {
        anchors.fill: parent
        colors: [page.hue, Theme.accent, Theme.blue]
    }

    KeyedModel {
        id: entries

        source: page.tab === 2 ? page.audio.streams : page.inputs ? page.audio.sources : page.audio.sinks
    }

    // ── the default device ──
    Row {
        id: hero

        x: Theme.px(24)
        y: Theme.px(24)
        width: parent.width - 2 * x
        spacing: Theme.px(20)

        Orb {
            id: orb

            level: page.master && !page.master.muted ? Math.min(1, masterSlider.shown / 100) : 0
            text: !page.master ? "–" : page.master.muted ? "MUTE" : Math.round(masterSlider.shown) + "%"
            color: page.hue
            pulsing: !!page.master && !page.master.muted

            TapHandler {
                onTapped: Daemon.send("audio.toggleMute", { kind: page.kind, id: "default" })
            }

            HoverHandler {
                cursorShape: Qt.PointingHandCursor
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - orb.width - parent.spacing
            spacing: Theme.px(4)

            Txt {
                width: parent.width
                text: page.master?.description ?? (page.inputs ? "No input device" : "No output device")
                size: 16
                bold: true
            }

            Txt {
                width: parent.width
                text: page.tab === 2 ? "Master output volume" : page.inputs ? "Default input" : "Default output"
                size: 12
                color: Theme.subtext
            }

            Item {
                width: 1
                height: Theme.px(10)
            }

            Slide {
                id: masterSlider

                width: parent.width
                to: 100
                step: 5
                thickness: 10
                value: page.master?.volume ?? 0
                accentColor: page.hue
                interactive: !!page.master
                onMoved: value => page.setVolume(page.kind, "default", value)
            }
        }
    }

    Tabs {
        id: tabs

        anchors.top: hero.bottom
        anchors.topMargin: Theme.px(24)
        x: Theme.px(24)
        width: parent.width - 2 * x
        model: [{ label: "Outputs", icon: Icons.speaker }, { label: "Inputs", icon: Icons.mic }, { label: "Apps", icon: Icons.apps }]
        current: page.tab
        accentColor: page.hue
        onSelected: index => page.tab = index
    }

    Txt {
        anchors.centerIn: list
        visible: entries.count === 0
        text: page.tab === 2 ? "Nothing is playing" : "No devices"
        color: Theme.dim
    }

    List {
        id: list

        anchors.top: tabs.bottom
        anchors.bottom: parent.bottom
        anchors.topMargin: Theme.px(16)
        anchors.bottomMargin: Theme.px(20)
        x: Theme.px(24)
        width: parent.width - 2 * x
        spacing: Theme.px(8)
        model: entries.rows

        add: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.normal }
        }
        displaced: Transition {
            NumberAnimation { property: "y"; duration: Theme.normal; easing.type: Easing.OutCubic }
        }

        delegate: Card {
            id: card

            required property string key
            readonly property var entry: entries.byKey[key] ?? ({})
            readonly property bool isStream: page.tab === 2
            readonly property bool isDefault: !isStream && !!entry.default
            readonly property string entryKind: isStream ? "stream" : page.kind
            // The default device is controlled by the orb, so its card stays compact.
            readonly property bool expanded: !isDefault

            width: list.width
            implicitHeight: content.implicitHeight + Theme.px(24)
            color: isDefault ? Theme.alpha(page.hue, 0.14) : Theme.alpha(Theme.surface0, hover.hovered ? 0.8 : 0.55)
            border.color: isDefault ? Theme.alpha(page.hue, 0.5) : Theme.border

            Behavior on color {
                ColorAnimation { duration: Theme.fast }
            }

            HoverHandler {
                id: hover
            }

            // Clicking a device makes it the default.
            TapHandler {
                enabled: !card.isStream && !card.isDefault
                onTapped: Daemon.send("audio.setDefault", { kind: page.kind, name: card.entry.name })
            }

            Column {
                id: content

                x: Theme.px(14)
                y: Theme.px(12)
                width: parent.width - 2 * x
                spacing: Theme.px(10)

                Row {
                    width: parent.width
                    spacing: Theme.px(12)

                    Item {
                        id: badge

                        width: Theme.px(36)
                        height: Theme.px(36)

                        Rectangle {
                            anchors.fill: parent
                            visible: !card.isStream
                            radius: Theme.px(10)
                            color: card.isDefault ? page.hue : Theme.alpha(Theme.surface2, 0.6)

                            Icon {
                                anchors.centerIn: parent
                                text: page.inputs ? Icons.mic : Icons.device(card.entry.kind, Icons.speaker)
                                size: 19
                                color: card.isDefault ? Theme.accentText : Theme.text
                            }
                        }

                        AppIcon {
                            anchors.centerIn: parent
                            visible: card.isStream
                            icon: card.entry.icon ?? ""
                            glyph: Icons.musicNote
                            size: 32
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - badge.width - parent.spacing

                        Txt {
                            width: parent.width
                            text: (card.isStream ? card.entry.app : card.entry.description) ?? ""
                            size: 13
                            bold: true
                        }

                        Txt {
                            width: parent.width
                            text: card.isStream ? (card.entry.media ?? "") : card.isDefault ? "Active" : "Click to make default"
                            size: 11
                            color: card.isDefault ? page.hue : Theme.subtext
                        }
                    }
                }

                Row {
                    visible: card.expanded
                    width: parent.width
                    spacing: Theme.px(10)

                    IconBtn {
                        id: mute

                        anchors.verticalCenter: parent.verticalCenter
                        icon: Icons.volume(card.entry.volume ?? 0, card.entry.muted)
                        size: 28
                        iconColor: card.entry.muted ? Theme.red : Theme.subtext
                        onClicked: Daemon.send("audio.toggleMute", { kind: card.entryKind, id: card.entry.id })
                    }

                    Slide {
                        id: slider

                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - mute.width - percent.width - 2 * parent.spacing
                        to: 100
                        step: 5
                        value: card.entry.volume ?? 0
                        accentColor: card.entry.muted ? Theme.dim : page.hue
                        onMoved: value => page.setVolume(card.entryKind, card.entry.id, value)
                    }

                    Txt {
                        id: percent

                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.px(38)
                        horizontalAlignment: Text.AlignRight
                        text: Math.round(slider.shown) + "%"
                        size: 12
                        color: Theme.subtext
                    }
                }
            }
        }
    }
}
