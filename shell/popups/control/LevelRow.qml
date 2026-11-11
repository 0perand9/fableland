import QtQuick
import qs.core
import qs.widgets

// One level to set: an icon, a slider and the value in percent. With
// `toggles` the icon is a button (mute).
Item {
    id: root

    property string icon: ""
    property color hue: Theme.accent
    // 0 … 100, as the daemon reports it.
    property real value: 0
    // Drawn greyed out, with the icon in red.
    property bool muted: false
    property bool toggles: false

    signal moved(real value)
    signal toggled

    implicitHeight: Theme.px(30)

    Clickable {
        id: badge

        width: Theme.px(30)
        height: width
        radius: width / 2
        interactive: root.toggles
        onClicked: root.toggled()

        Icon {
            anchors.centerIn: parent
            text: root.icon
            size: 19
            color: root.muted ? Theme.red : root.hue
        }
    }

    Slide {
        id: slider

        anchors.left: badge.right
        anchors.leftMargin: Theme.px(10)
        anchors.right: percent.left
        anchors.rightMargin: Theme.px(10)
        anchors.verticalCenter: parent.verticalCenter
        to: 100
        step: 5
        thickness: 8
        value: root.value
        accentColor: root.muted ? Theme.dim : root.hue
        onMoved: value => root.moved(value)
    }

    Txt {
        id: percent

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.px(38)
        horizontalAlignment: Text.AlignRight
        text: Math.round(slider.shown) + "%"
        size: 12
        color: Theme.subtext
    }
}
