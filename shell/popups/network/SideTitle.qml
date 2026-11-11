import QtQuick
import qs.core
import qs.widgets

// The corner of the network popup that says which side is on show and how it
// is doing.
Row {
    id: root

    required property Side side

    spacing: Theme.px(12)

    Rectangle {
        width: Theme.px(44)
        height: width
        radius: Theme.radius
        color: Theme.alpha(root.side.hue, 0.16)

        Icon {
            anchors.centerIn: parent
            text: root.side.icon
            size: 23
            color: root.side.hue
        }
    }

    Column {
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.px(2)

        Txt {
            text: root.side.title
            size: 18
            bold: true
        }

        // Kept short: satellites pass close by.
        Txt {
            width: Math.min(implicitWidth, Theme.px(190))
            text: root.side.status
            size: 12
            color: Theme.subtext
        }
    }
}
