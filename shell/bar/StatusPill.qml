import QtQuick
import qs.core
import qs.widgets

// An icon (and optional label) in the status area. When `active` it is filled
// with a gradient of its `hue`.
Clickable {
    id: root

    property string icon: ""
    property string text: ""
    property color hue: Theme.accent
    property bool active: false
    property real maxTextWidth: Theme.px(120)

    readonly property color foreground: active ? Theme.base : Theme.text

    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    implicitWidth: row.implicitWidth + Theme.px(text === "" ? 16 : 22)
    implicitHeight: Theme.px(34)
    radius: Theme.px(10)
    fill: active ? "transparent" : Theme.alpha(Theme.surface1, 0.45)
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

    Behavior on implicitWidth {
        NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic }
    }

    Rectangle {
        anchors.fill: parent
        z: -1
        radius: parent.radius
        opacity: root.active ? 1 : 0
        gradient: Gradient {
            orientation: Gradient.Horizontal

            GradientStop { position: 0; color: root.hue }
            GradientStop { position: 1; color: Qt.lighter(root.hue, 1.18) }
        }

        Behavior on opacity {
            NumberAnimation { duration: Theme.normal }
        }
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: Theme.px(7)

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            size: 17
            color: root.foreground
        }

        Txt {
            visible: root.text !== ""
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, root.maxTextWidth)
            text: root.text
            size: 12
            bold: true
            color: root.foreground
        }
    }
}
