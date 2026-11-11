import QtQuick
import qs.core
import qs.widgets

// A card for one chart: a caption line — title on the left, a note on the
// right — above the chart itself. The charts use the note as their read-out:
// it tells what the pointer is on.
Card {
    id: root

    property string title: ""
    property string note: ""
    // The chart.
    default property alias content: body.data
    // Controls at the right end of the caption line.
    property alias trailing: controls.data

    Txt {
        id: caption

        anchors.left: parent.left
        anchors.right: readout.left
        anchors.leftMargin: Theme.pad
        anchors.rightMargin: Theme.gap
        y: Theme.px(12)
        text: root.title
        size: 12
        bold: true
        color: Theme.subtext
    }

    Txt {
        id: readout

        anchors.right: controls.left
        anchors.rightMargin: controls.width > 0 ? Theme.gap : 0
        anchors.verticalCenter: caption.verticalCenter
        text: root.note
        size: 11
        color: Theme.dim
    }

    Row {
        id: controls

        anchors.right: parent.right
        anchors.rightMargin: width > 0 ? Theme.px(10) : Theme.pad
        anchors.verticalCenter: caption.verticalCenter
    }

    Item {
        id: body

        anchors.fill: parent
        anchors.leftMargin: Theme.pad
        anchors.rightMargin: Theme.pad
        anchors.topMargin: Theme.px(38)
        anchors.bottomMargin: Theme.px(14)
    }
}
