import QtQuick
import qs.core
import qs.widgets

// One weather figure as a ring: the value inside, what it is underneath.
Column {
    id: gauge

    property string label: ""
    property string icon: ""
    property string value: ""
    property string unit: ""
    // 0 … 1: how much of the ring is drawn.
    property real fill: 0
    property color color: Theme.accent

    spacing: Theme.px(7)

    Ring {
        anchors.horizontalCenter: parent.horizontalCenter
        width: Theme.px(64)
        height: Theme.px(64)
        value: gauge.fill
        thickness: 4
        color: gauge.color

        Column {
            anchors.centerIn: parent

            Txt {
                anchors.horizontalCenter: parent.horizontalCenter
                text: gauge.value
                size: 15
                bold: true
            }

            Txt {
                anchors.horizontalCenter: parent.horizontalCenter
                text: gauge.unit
                size: 9
                color: Theme.dim
            }
        }
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Theme.px(4)

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            text: gauge.icon
            size: 12
            color: Theme.dim
        }

        Txt {
            anchors.verticalCenter: parent.verticalCenter
            text: gauge.label
            size: 10
            bold: true
            color: Theme.dim
        }
    }
}
