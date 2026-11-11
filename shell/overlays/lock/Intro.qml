import QtQuick
import qs.core
import qs.widgets

// The moment of locking: a padlock pops up in the middle of the screen, snaps
// shut and dissolves into the lock screen. `done` turns true when it is over.
Item {
    id: root

    property bool done: false
    // 0 → 1: the rings thrown off by the padlock appearing.
    property real burst: 0
    // 0 → 1: the shackle closing.
    property real shut: 0

    visible: !done

    Repeater {
        model: [{ size: 240, from: 0.8, to: 1.25, strength: 0.6 }, { size: 300, from: 0.8, to: 1.4, strength: 0.4 }, { size: 360, from: 0.5, to: 1.5, strength: 0.3 }]

        Rectangle {
            required property var modelData

            anchors.centerIn: parent
            width: Theme.px(modelData.size)
            height: width
            radius: width / 2
            color: "transparent"
            border.width: 1
            border.color: Theme.text
            scale: modelData.from + (modelData.to - modelData.from) * root.burst
            opacity: modelData.strength * (1 - root.burst)
        }
    }

    Rectangle {
        id: orb

        anchors.centerIn: parent
        width: Theme.px(170)
        height: width
        radius: width / 2
        color: Theme.alpha(Theme.surface0, 0.9)
        border.width: Theme.px(2)
        border.color: Theme.text
        scale: 0
        opacity: 0

        Icon {
            anchors.centerIn: parent
            text: Icons.unlock
            size: 64
            scale: 1 - 0.5 * root.shut
            opacity: 1 - 2 * root.shut
        }

        Icon {
            anchors.centerIn: parent
            text: Icons.lock
            size: 64
            scale: 1.6 - 0.6 * root.shut
            opacity: 2 * root.shut
        }
    }

    SequentialAnimation {
        running: true
        onFinished: root.done = true

        ParallelAnimation {
            NumberAnimation { target: orb; property: "scale"; from: 0; to: 1; duration: 300; easing.type: Easing.OutCubic }
            NumberAnimation { target: orb; property: "opacity"; from: 0; to: 1; duration: 200; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "burst"; from: 0; to: 1; duration: 350; easing.type: Easing.OutCubic }
        }
        NumberAnimation { target: root; property: "shut"; from: 0; to: 1; duration: 200; easing.type: Easing.OutBack }
        PauseAnimation { duration: 60 }
        ParallelAnimation {
            NumberAnimation { target: orb; property: "scale"; to: 1.8; duration: 120; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "opacity"; to: 0; duration: 120; easing.type: Easing.InCubic }
        }
    }
}
