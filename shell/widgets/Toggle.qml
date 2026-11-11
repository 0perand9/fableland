import QtQuick
import qs.core

// An on/off switch. It does not flip itself: bind `checked` to state and
// change that state in onToggled, so the switch always shows the truth.
Item {
    id: root

    property bool checked: false
    property color accentColor: Theme.accent
    property bool interactive: true

    signal toggled(bool checked)

    implicitWidth: Theme.px(44)
    implicitHeight: Theme.px(24)
    opacity: interactive ? 1 : 0.45

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? root.accentColor : Theme.alpha(Theme.surface2, 0.8)

        Behavior on color {
            ColorAnimation { duration: Theme.normal }
        }
    }

    Rectangle {
        readonly property int inset: Theme.px(3)

        y: inset
        x: root.checked ? root.width - width - inset : inset
        // The knob stretches towards the pointer while pressed.
        width: height + (mouse.pressed ? Theme.px(6) : 0)
        height: root.height - 2 * inset
        radius: height / 2
        color: root.checked ? Theme.accentText : Theme.text

        Behavior on x {
            NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic }
        }
        Behavior on width {
            NumberAnimation { duration: Theme.fast }
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        enabled: root.interactive
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}
