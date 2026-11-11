import QtQuick
import Quickshell.Widgets
import qs.core

// A button for actions that must not happen by accident (power off, wipe, ...):
// it fires only after being held until the liquid has filled it.
ClippingRectangle {
    id: root

    property string text: ""
    property string icon: ""
    property color accentColor: Theme.red
    property int holdMs: 900
    property real size: 13
    property real iconSize: size + 6
    // Stack the icon above the label (for square tiles).
    property bool vertical: false
    readonly property real progress: fill.level
    readonly property bool hovered: mouse.containsMouse

    signal triggered

    implicitWidth: content.implicitWidth + Theme.px(32)
    implicitHeight: vertical ? content.implicitHeight + Theme.px(28) : Theme.px(40)
    radius: Theme.radiusSmall
    color: Theme.alpha(Theme.surface1, hovered ? 0.9 : 0.6)
    border.width: 1
    border.color: Theme.alpha(accentColor, hovered || progress > 0 ? 0.5 : 0.15)

    Behavior on color {
        ColorAnimation { duration: Theme.fast }
    }

    Wave {
        id: fill

        anchors.fill: parent
        color: root.accentColor
        level: 0
        running: level > 0 && level < 1

        states: State {
            name: "holding"
            when: mouse.pressed
            PropertyChanges { fill.level: 1 }
        }
        transitions: [
            Transition {
                to: "holding"
                SequentialAnimation {
                    NumberAnimation { property: "level"; duration: root.holdMs; easing.type: Easing.InOutSine }
                    ScriptAction { script: root.triggered() }
                }
            },
            Transition {
                from: "holding"
                NumberAnimation { property: "level"; duration: Theme.normal; easing.type: Easing.OutCubic }
            }
        ]
    }

    Grid {
        id: content

        anchors.centerIn: parent
        columns: root.vertical ? 1 : 2
        spacing: Theme.px(8)
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter

        Icon {
            visible: root.icon !== ""
            text: root.icon
            size: root.iconSize
            color: label.color
        }

        Txt {
            id: label

            visible: root.text !== ""
            text: root.text
            size: root.size
            bold: true
            color: root.progress > 0.55 ? Theme.accentText : root.hovered ? root.accentColor : Theme.text

            Behavior on color {
                ColorAnimation { duration: Theme.fast }
            }
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
    }
}
