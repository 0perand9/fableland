import QtQuick
import qs.core

// One of the floating pills the bar is made of. Children are laid out in a row.
Rectangle {
    id: root

    default property alias content: row.data
    property alias spacing: row.spacing
    property real padding: Theme.px(7)
    // Position in the start-up cascade.
    property int order: 0

    implicitWidth: row.implicitWidth + 2 * padding
    implicitHeight: Theme.barHeight
    radius: Theme.radius
    color: Theme.alpha(Theme.base, 0.78)
    border.width: 1
    border.color: Theme.border

    Row {
        id: row

        anchors.centerIn: parent
        height: parent.height
        spacing: Theme.px(4)
    }

    // Groups drop in one after another when the bar appears. (The drop starts
    // from the animation's `from`: bound here, it would snap back up whenever
    // the scale changes.)
    opacity: 0
    transform: Translate { id: drop }

    SequentialAnimation {
        running: true

        PauseAnimation { duration: 60 + root.order * 70 }
        ParallelAnimation {
            NumberAnimation { target: root; property: "opacity"; to: 1; duration: Theme.slow; easing.type: Easing.OutCubic }
            NumberAnimation { target: drop; property: "y"; from: -Theme.px(16); to: 0; duration: Theme.slow; easing.type: Easing.OutBack }
        }
    }
}
