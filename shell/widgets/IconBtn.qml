import QtQuick
import qs.core

// A button that is just an icon. `size` is the button's side in design units.
Clickable {
    id: root

    property string icon: ""
    property real size: 34
    property real iconSize: size * 0.56
    property color iconColor: Theme.text
    // Draws the button as selected: filled with `accentColor`.
    property bool active: false
    property color accentColor: Theme.accent

    implicitWidth: Theme.px(size)
    implicitHeight: Theme.px(size)
    radius: height / 2
    fill: active ? accentColor : "transparent"

    Icon {
        anchors.centerIn: parent
        text: root.icon
        size: root.iconSize
        color: root.active ? Theme.accentText : root.iconColor
        opacity: root.interactive ? 1 : 0.4
    }
}
