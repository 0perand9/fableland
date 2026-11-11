import QtQuick
import qs.core
import qs.widgets

// A line of code with a button that copies it to the clipboard.
Rectangle {
    id: root

    property string code: ""

    implicitHeight: Theme.px(38)
    radius: Theme.radiusSmall
    color: Theme.alpha(Theme.crust, 0.75)
    border.width: 1
    border.color: Theme.border

    Txt {
        anchors.left: parent.left
        anchors.right: copy.left
        anchors.leftMargin: Theme.px(14)
        anchors.rightMargin: Theme.px(8)
        anchors.verticalCenter: parent.verticalCenter
        text: root.code
        size: 12
        color: Theme.accent
    }

    IconBtn {
        id: copy

        anchors.right: parent.right
        anchors.rightMargin: Theme.px(5)
        anchors.verticalCenter: parent.verticalCenter
        size: 28
        icon: copied.running ? Icons.check : Icons.copy
        iconColor: copied.running ? Theme.green : Theme.dim
        onClicked: {
            Daemon.send("clipboard.copyText", { text: root.code });
            copied.restart();
        }
    }

    // How long the tick stays after copying.
    Timer {
        id: copied

        interval: 1400
    }
}
