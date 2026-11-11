import QtQuick
import qs.core
import qs.widgets

// The buttons under a timer: start/pause in the middle, an optional action on
// either side. The middle button keeps its place whichever sides are in use.
Row {
    id: root

    property bool running: false
    property color hue: Theme.accent
    property bool startable: true
    // Icons of the side actions; "" leaves that side empty.
    property string leftIcon: ""
    property string rightIcon: ""
    property bool leftActive: false

    signal toggled
    signal leftClicked
    signal rightClicked

    spacing: Theme.px(20)

    component Side: IconBtn {
        size: 44
        iconSize: 20
        iconColor: Theme.subtext
        fill: active ? accentColor : Theme.alpha(Theme.surface1, 0.7)
        opacity: icon === "" ? 0 : 1
        interactive: icon !== ""
    }

    Side {
        anchors.verticalCenter: parent.verticalCenter
        icon: root.leftIcon
        active: root.leftActive
        accentColor: root.hue
        onClicked: root.leftClicked()
    }

    IconBtn {
        icon: root.running ? Icons.pause : Icons.play
        size: 56
        iconSize: 28
        active: true
        accentColor: root.hue
        interactive: root.running || root.startable
        opacity: interactive ? 1 : 0.45
        onClicked: root.toggled()
    }

    Side {
        anchors.verticalCenter: parent.verticalCenter
        icon: root.rightIcon
        accentColor: root.hue
        onClicked: root.rightClicked()
    }
}
