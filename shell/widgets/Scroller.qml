import QtQuick
import qs.core

// A thin scroll indicator for a Flickable. Place it as a sibling (or child) of
// the flickable and set `target`; it positions itself along the right edge.
Rectangle {
    id: root

    required property Flickable target
    readonly property real ratio: target.visibleArea.heightRatio

    x: target.x + target.width - width - Theme.px(2)
    y: target.y + target.visibleArea.yPosition * target.height
    width: Theme.px(4)
    height: Math.max(Theme.px(24), ratio * target.height)
    radius: width / 2
    color: Theme.alpha(Theme.text, 0.3)
    visible: ratio < 1
    opacity: target.moving || linger.running ? 1 : 0

    Behavior on opacity {
        NumberAnimation { duration: Theme.normal }
    }

    Connections {
        target: root.target

        function onContentYChanged() {
            linger.restart();
        }
    }

    Timer {
        id: linger

        interval: 900
    }
}
