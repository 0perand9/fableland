import QtQuick
import qs.core
import qs.widgets

// A colour of the palette: a sample, its name and what it is used for (or its value).
Card {
    id: root

    property color sample: Theme.accent
    property string name: ""
    property string note: ""

    implicitHeight: Theme.px(50)

    Rectangle {
        id: chip

        x: Theme.px(9)
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.px(32)
        height: Theme.px(32)
        radius: Theme.px(8)
        color: root.sample
        border.width: 1
        border.color: Theme.border
    }

    Column {
        anchors.left: chip.right
        anchors.right: parent.right
        anchors.leftMargin: Theme.px(10)
        anchors.rightMargin: Theme.px(8)
        anchors.verticalCenter: parent.verticalCenter

        Txt {
            width: parent.width
            text: root.name
            size: 12
            bold: true
        }

        Txt {
            width: parent.width
            text: root.note
            size: 10
            color: Theme.dim
        }
    }
}
