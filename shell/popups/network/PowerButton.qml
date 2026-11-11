import QtQuick
import qs.core
import qs.widgets

// The power switch of a side. While the side is off it stands big in the hub's
// place, with a line saying so; switched on, it shrinks into its dock in the
// corner. Position it by `center`: the item itself has no size.
Item {
    id: root

    property bool on: false
    property color hue: Theme.accent
    property string offTitle: ""
    property string offHint: ""
    // Where the button's centre is while off and while on, in the parent's coordinates.
    property point restCenter
    property point dockCenter

    // 0 off (big, in the middle) … 1 on (small, docked).
    property real pose: on ? 1 : 0
    readonly property real diameter: Theme.px(160) + (Theme.px(44) - Theme.px(160)) * pose

    signal toggled

    x: restCenter.x + (dockCenter.x - restCenter.x) * pose
    y: restCenter.y + (dockCenter.y - restCenter.y) * pose

    Behavior on pose {
        NumberAnimation { duration: 600; easing.type: Easing.InOutQuint }
    }

    Clickable {
        id: button

        x: -width / 2
        y: -height / 2
        width: root.diameter
        height: root.diameter
        radius: width / 2
        fill: Theme.mix(Theme.surface1, root.hue, root.pose)
        tint: Theme.mix(root.hue, Theme.accentText, root.pose)
        border.width: Theme.px(2)
        border.color: Theme.alpha(root.hue, 0.35 * (1 - root.pose))
        scale: pressed ? 0.95 : hovered ? 1.05 : 1
        onClicked: root.toggled()

        Behavior on scale {
            NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic }
        }

        Icon {
            anchors.centerIn: parent
            text: Icons.power
            size: 64 + (22 - 64) * root.pose
            color: Theme.mix(Theme.text, Theme.accentText, root.pose)
        }
    }

    Column {
        anchors.horizontalCenter: button.horizontalCenter
        anchors.top: button.bottom
        anchors.topMargin: Theme.px(18)
        spacing: Theme.px(4)
        // Fades away during the first half of the way to the dock.
        opacity: 1 - Math.min(1, root.pose * 2)
        visible: opacity > 0

        Txt {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.offTitle
            size: 16
            bold: true
        }

        Txt {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.offHint
            size: 12
            color: Theme.subtext
        }
    }
}
