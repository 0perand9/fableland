import QtQuick
import qs.core

// Dots travelling from left to right: "this feeds that".
Item {
    id: root

    property var colors: [Theme.accent, Theme.secondary, Theme.tertiary]
    property bool running: visible

    implicitWidth: Theme.px(84)
    implicitHeight: Theme.px(8)

    Repeater {
        model: root.colors

        Rectangle {
            id: dot

            required property color modelData
            required property int index

            width: root.height
            height: root.height
            radius: height / 2
            color: modelData
            opacity: 0

            SequentialAnimation {
                running: root.running
                loops: Animation.Infinite

                // Each dot leaves a little after the one before it.
                PauseAnimation { duration: dot.index * 400 }
                ParallelAnimation {
                    NumberAnimation { target: dot; property: "x"; from: 0; to: root.width - dot.width; duration: 1200; easing.type: Easing.InOutSine }
                    SequentialAnimation {
                        NumberAnimation { target: dot; property: "opacity"; from: 0; to: 1; duration: 300 }
                        PauseAnimation { duration: 600 }
                        NumberAnimation { target: dot; property: "opacity"; from: 1; to: 0; duration: 300 }
                    }
                }
                PauseAnimation { duration: (root.colors.length - 1 - dot.index) * 400 }
            }
        }
    }
}
