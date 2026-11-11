import QtQuick
import qs.core
import qs.widgets

// A capsule in the row at the bottom of the lock screen: an icon and a short
// text, optionally followed by whatever is put inside it.
Rectangle {
    id: root

    property string icon: ""
    property string text: ""
    // Colour of the icon and of the border under the pointer.
    property color hue: Theme.accent
    property color textColor: Theme.text
    // Whether clicking it does something.
    property bool interactive: false
    default property alias content: row.data

    signal clicked

    implicitWidth: row.implicitWidth + Theme.px(36)
    implicitHeight: Theme.px(48)
    radius: height / 2
    color: hover.hovered ? Theme.alpha(Theme.surface1, 0.6) : Theme.alpha(Theme.surface0, 0.4)
    border.width: 1
    border.color: hover.hovered ? hue : Theme.border
    scale: hover.hovered ? 1.04 : 1

    Behavior on color {
        ColorAnimation { duration: Theme.normal }
    }
    Behavior on border.color {
        ColorAnimation { duration: Theme.normal }
    }
    Behavior on scale {
        NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic }
    }

    HoverHandler {
        id: hover

        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
    }

    TapHandler {
        enabled: root.interactive
        onTapped: root.clicked()
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: Theme.px(8)

        Icon {
            visible: root.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            size: 20
            color: root.hue
        }

        Txt {
            visible: root.text !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            size: 14
            bold: true
            color: root.textColor
        }
    }
}
