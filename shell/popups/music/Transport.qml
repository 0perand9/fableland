import QtQuick
import qs.core
import qs.widgets

// Previous · play/pause · next for the active player.
Row {
    id: root

    readonly property var media: Daemon.media
    readonly property bool playing: media.status === "Playing"

    spacing: Theme.px(22)
    onPlayingChanged: {
        if (playing)
            ripple.restart();
    }

    IconBtn {
        anchors.verticalCenter: parent.verticalCenter
        icon: Icons.previous
        size: 40
        iconSize: 24
        interactive: root.media.available && root.media.canPrev
        onClicked: Daemon.send("media.previous")
    }

    IconBtn {
        anchors.verticalCenter: parent.verticalCenter
        icon: root.playing ? Icons.pause : Icons.play
        size: 52
        iconSize: 30
        active: root.media.available
        interactive: root.media.available
        onClicked: Daemon.send("media.playPause")

        // A ring that spreads out each time playback starts.
        Rectangle {
            id: ring

            anchors.fill: parent
            z: -1
            radius: width / 2
            color: Theme.accent
            opacity: 0
        }

        ParallelAnimation {
            id: ripple

            NumberAnimation { target: ring; property: "scale"; from: 1; to: 1.8; duration: 500; easing.type: Easing.OutQuart }
            NumberAnimation { target: ring; property: "opacity"; from: 0.5; to: 0; duration: 500; easing.type: Easing.OutQuart }
        }
    }

    IconBtn {
        anchors.verticalCenter: parent.verticalCenter
        icon: Icons.next
        size: 40
        iconSize: 24
        interactive: root.media.available && root.media.canNext
        onClicked: Daemon.send("media.next")
    }
}
