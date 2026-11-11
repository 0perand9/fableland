import QtQuick
import qs.core

// The playback position of the active player, in seconds. The daemon reports a
// position and when it was measured; this extrapolates while `active`.
Item {
    id: root

    property bool active: true
    readonly property var media: Daemon.media
    readonly property bool playing: media.status === "Playing"
    property real now: Date.now()
    readonly property real position: {
        const elapsed = playing ? Math.max(0, now - media.positionAt) / 1000 * (media.rate || 1) : 0;
        const p = media.position + elapsed;
        return media.length > 0 ? Math.min(media.length, p) : p;
    }
    readonly property real progress: media.length > 0 ? position / media.length : 0

    visible: false
    onMediaChanged: now = Date.now()

    Timer {
        interval: 500
        repeat: true
        running: root.active && root.playing
        triggeredOnStart: true
        onTriggered: root.now = Date.now()
    }
}
