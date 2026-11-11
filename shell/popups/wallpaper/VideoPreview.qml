import QtQuick
import QtMultimedia
import qs.core

// A video wallpaper playing silently in its card. Created only for the focused
// card (see WallCard), so at most one video is ever decoded.
Item {
    id: root

    // File URL of the video.
    property url source
    // Frames are arriving: the still underneath can be covered.
    readonly property bool playing: player.playbackState === MediaPlayer.PlayingState && player.position > 0

    // No audio output: the preview stays silent and never shows up in the mixer.
    MediaPlayer {
        id: player

        source: root.source
        autoPlay: true
        loops: MediaPlayer.Infinite
        videoOutput: output
    }

    VideoOutput {
        id: output

        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
        opacity: root.playing ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Theme.normal }
        }
    }
}
