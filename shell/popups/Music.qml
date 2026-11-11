import QtQuick
import qs.core
import qs.widgets
import qs.popups.music

// What is playing — the record, the track, seeking and transport — with the
// system equalizer below. Space plays or pauses, ←/→ seek, N and P skip.
PopupPage {
    id: page

    readonly property var media: Daemon.media
    readonly property bool playing: media.status === "Playing"
    readonly property bool seekable: media.available && media.canSeek && media.length > 0
    readonly property var output: Daemon.audio.sink

    // The cover's colours as one string: it changes only when the colours do,
    // whereas the topic itself is republished every few seconds while playing.
    readonly property string paletteKey: (media.palette ?? []).join(" ")
    readonly property var coverColors: paletteKey === "" ? [Theme.accent, Theme.secondary, Theme.tertiary] : paletteKey.split(" ").map(hex => luminous(Qt.color(hex)))

    // Covers are often dark: lift a colour until it glows on the popup's background.
    function luminous(c) {
        const lightness = Math.max(0.6, c.hslLightness);
        return c.hslSaturation < 0.05 ? Qt.hsla(0, 0, lightness, 1) : Qt.hsla(c.hslHue, Math.min(1, c.hslSaturation + 0.15), lightness, 1);
    }

    function seekTo(seconds) {
        if (seekable)
            Daemon.send("media.seek", { position: Math.max(0, Math.min(media.length, seconds)) });
    }

    implicitWidth: Theme.px(700)
    implicitHeight: content.implicitHeight + 2 * content.y
    placement: "top-left"

    Keys.onPressed: event => {
        if (!media.available)
            return;
        switch (event.key) {
        case Qt.Key_Space: Daemon.send("media.playPause"); break;
        case Qt.Key_Left: seekTo(clock.position - 5); break;
        case Qt.Key_Right: seekTo(clock.position + 5); break;
        case Qt.Key_N: Daemon.send("media.next"); break;
        case Qt.Key_P: Daemon.send("media.previous"); break;
        default: return;
        }
        event.accepted = true;
    }

    // The cover's colours behind everything. A new cover fades in rather than snapping.
    Backdrop {
        id: backdrop

        anchors.fill: parent
        strength: 0.2
        Component.onCompleted: colors = page.coverColors

        Connections {
            target: page

            function onCoverColorsChanged() {
                recolour.restart();
            }
        }

        SequentialAnimation {
            id: recolour

            NumberAnimation { target: backdrop; property: "opacity"; to: 0; duration: Theme.normal }
            ScriptAction { script: backdrop.colors = page.coverColors }
            NumberAnimation { target: backdrop; property: "opacity"; to: 1; duration: Theme.slow }
        }
    }

    MediaClock {
        id: clock
    }

    Column {
        id: content

        x: Theme.px(24)
        y: Theme.px(24)
        width: parent.width - 2 * x
        spacing: Theme.px(20)

        Row {
            width: parent.width
            spacing: Theme.px(24)

            Vinyl {
                id: vinyl

                art: Fmt.file(page.media.art)
                spinning: page.playing
                glow: page.coverColors[0]
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - vinyl.width - parent.spacing
                spacing: Theme.px(10)

                Column {
                    width: parent.width
                    spacing: Theme.px(4)

                    Marquee {
                        width: parent.width
                        text: page.media.available ? (page.media.title || "Unknown title") : "Nothing is playing"
                        size: 20
                        bold: true
                    }

                    Txt {
                        width: parent.width
                        text: page.media.available ? ([page.media.artist, page.media.album].filter(Boolean).join("  ·  ") || "Unknown artist") : "Start something in any player and it shows up here"
                        size: 13
                        color: Theme.subtext
                    }
                }

                Row {
                    spacing: Theme.px(8)

                    // Where the sound goes; the mixer is one click away.
                    Chip {
                        visible: !!page.output
                        glyph: Icons.device(page.output?.kind, Icons.speaker)
                        glyphColor: Theme.peach
                        text: page.output?.description ?? ""
                        onClicked: Ui.open("volume")
                    }

                    Chip {
                        visible: page.media.available
                        glyph: Icons.music
                        appIcon: page.media.desktopEntry ?? ""
                        text: page.media.name ?? ""
                        interactive: false
                    }
                }

                Column {
                    width: parent.width

                    Slide {
                        id: seek

                        width: parent.width
                        to: Math.max(1, page.media.length)
                        step: 5
                        thickness: 8
                        value: page.seekable ? clock.position : 0
                        interactive: page.seekable
                        // Dragging seeks once, on release; a wheel notch seeks right away.
                        onMoved: value => {
                            if (!dragging)
                                page.seekTo(value);
                        }
                        onReleased: value => page.seekTo(value)
                    }

                    Item {
                        width: parent.width
                        height: elapsed.implicitHeight

                        Txt {
                            id: elapsed

                            text: page.media.available ? Fmt.clock(seek.held ? seek.shown : clock.position) : "–:––"
                            size: 11
                            color: Theme.subtext
                        }

                        Txt {
                            anchors.right: parent.right
                            text: page.media.length > 0 ? Fmt.clock(page.media.length) : "–:––"
                            size: 11
                            color: Theme.subtext
                        }
                    }
                }

                Transport {
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }

        PlayerSwitch {
            visible: page.media.players.length > 1
            width: parent.width
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.border
        }

        Equalizer {
            width: parent.width
        }
    }
}
