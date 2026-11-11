import QtQuick
import qs.core
import qs.widgets

// What is playing, with transport controls. Clicking it opens the music popup.
BarGroup {
    id: root

    required property var screen
    property real maxTitleWidth: Theme.px(220)

    readonly property var media: Daemon.media
    readonly property bool shown: media.available && media.title !== ""

    visible: shown
    padding: Theme.px(8)
    spacing: Theme.px(10)

    MediaClock {
        id: clock

        active: root.shown
    }

    Clickable {
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: info.implicitWidth + Theme.px(8)
        implicitHeight: Theme.px(36)
        onClicked: Ui.toggle("music", "", root.screen)

        Row {
            id: info

            anchors.verticalCenter: parent.verticalCenter
            x: Theme.px(2)
            spacing: Theme.px(10)

            RoundImage {
                id: cover

                anchors.verticalCenter: parent.verticalCenter
                width: Theme.px(32)
                height: Theme.px(32)
                radius: Theme.px(8)
                source: Fmt.file(root.media.art)

                Icon {
                    anchors.centerIn: parent
                    visible: !cover.loaded
                    text: Icons.musicNote
                    size: 16
                    color: Theme.subtext
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(root.maxTitleWidth, Math.max(title.implicitWidth, detail.implicitWidth))

                Marquee {
                    id: title

                    width: parent.width
                    text: root.media.title
                    size: 12
                    bold: true
                }

                Txt {
                    id: detail

                    width: parent.width
                    text: root.media.length > 0 ? Fmt.clock(clock.position) + " / " + Fmt.clock(root.media.length) : (root.media.artist || root.media.name || "")
                    size: 10
                    color: Theme.subtext
                }
            }
        }
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter

        IconBtn {
            icon: Icons.previous
            size: 28
            interactive: root.media.canPrev
            onClicked: Daemon.send("media.previous")
        }

        IconBtn {
            icon: clock.playing ? Icons.pause : Icons.play
            size: 28
            iconColor: Theme.accent
            onClicked: Daemon.send("media.playPause")
        }

        IconBtn {
            icon: Icons.next
            size: 28
            interactive: root.media.canNext
            onClicked: Daemon.send("media.next")
        }
    }
}
