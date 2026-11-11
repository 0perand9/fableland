import QtQuick
import qs.core
import qs.widgets

// A labelled number with − and + beside it. Like the other controls it does
// not change itself: bind `value` and apply the change in onMoved.
Item {
    id: root

    property string label: ""
    property int value: 0
    property int step: 1
    property int from: 1
    property int to: 99
    property string unit: ""

    signal moved(int value)

    implicitWidth: Theme.px(260)
    implicitHeight: Theme.px(32)

    Txt {
        anchors.left: parent.left
        anchors.right: buttons.left
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        size: 13
        color: Theme.subtext
    }

    Row {
        id: buttons

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.px(4)

        IconBtn {
            icon: Icons.minus
            size: 28
            fill: Theme.alpha(Theme.surface1, 0.7)
            interactive: root.value > root.from
            onClicked: root.moved(Math.max(root.from, root.value - root.step))
        }

        Txt {
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.px(64)
            horizontalAlignment: Text.AlignHCenter
            text: root.value + root.unit
            size: 13
            bold: true
        }

        IconBtn {
            icon: Icons.plus
            size: 28
            fill: Theme.alpha(Theme.surface1, 0.7)
            interactive: root.value < root.to
            onClicked: root.moved(Math.min(root.to, root.value + root.step))
        }
    }
}
