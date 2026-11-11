import QtQuick
import qs.core
import qs.widgets

// What is playing, with transport controls — music can be paused or skipped
// without unlocking.
Pill {
    id: root

    readonly property var media: Daemon.media

    visible: media.available && media.title !== ""

    RoundImage {
        id: art

        anchors.verticalCenter: parent.verticalCenter
        width: Theme.px(32)
        height: Theme.px(32)
        radius: width / 2
        source: Fmt.file(root.media.art)

        Icon {
            anchors.centerIn: parent
            visible: !art.loaded
            text: Icons.musicNote
            size: 16
            color: Theme.subtext
        }
    }

    Column {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(Theme.px(220), Math.max(title.implicitWidth, artist.implicitWidth))

        Txt {
            id: title

            width: parent.width
            text: root.media.title
            size: 13
            bold: true
        }

        Txt {
            id: artist

            width: parent.width
            visible: text !== ""
            text: root.media.artist || root.media.name || ""
            size: 11
            color: Theme.subtext
        }
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter

        IconBtn {
            icon: Icons.previous
            size: 30
            interactive: root.media.canPrev
            onClicked: Daemon.send("media.previous")
        }

        IconBtn {
            icon: root.media.status === "Playing" ? Icons.pause : Icons.play
            size: 30
            iconColor: Theme.accent
            onClicked: Daemon.send("media.playPause")
        }

        IconBtn {
            icon: Icons.next
            size: 30
            interactive: root.media.canNext
            onClicked: Daemon.send("media.next")
        }
    }
}
