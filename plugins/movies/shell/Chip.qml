import QtQuick
import qs.core
import qs.widgets

// A pill: a sort order, a season, a genre, a remembered search. `removable`
// adds a small button that asks for the pill to go away.
Clickable {
    id: root

    property string text: ""
    property bool active: false
    property bool removable: false
    property color hue: Theme.accent
    property real size: 12

    readonly property color foreground: active ? Theme.accentText : Theme.text

    signal removed

    implicitWidth: label.implicitWidth + Theme.px(removable ? 42 : 26)
    implicitHeight: Theme.px(32)
    radius: height / 2
    fill: active ? hue : Theme.alpha(Theme.surface0, 0.6)
    tint: foreground
    border.width: 1
    border.color: active ? hue : Theme.border

    Txt {
        id: label

        x: Theme.px(13)
        anchors.verticalCenter: parent.verticalCenter
        text: root.text
        size: root.size
        bold: root.active
        color: root.foreground
    }

    IconBtn {
        visible: root.removable
        anchors.right: parent.right
        anchors.rightMargin: Theme.px(5)
        anchors.verticalCenter: parent.verticalCenter
        size: 22
        icon: Icons.close
        iconColor: Theme.dim
        onClicked: root.removed()
    }
}
