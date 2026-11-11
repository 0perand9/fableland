import QtQuick
import Quickshell.Widgets
import qs.core
import qs.widgets

// One reading of the system monitor: a ring for its level, the figures beside
// it and, along the bottom, how it went over the last minutes.
ClippingRectangle {
    id: tile

    property string icon: ""
    property string title: ""
    property string value: ""
    property string detail: ""
    // 0 … 1; negative for a reading without a level (the ring stays empty).
    property real level: 0
    property color hue: Theme.accent
    // The ring turns red from this level on.
    property real alarm: 2
    // History graphs on one common scale, each { values, color }.
    property var series: []
    property real ceiling: 100
    // Extra content beside the figures, right-aligned.
    default property alias aside: aside.data

    readonly property color shade: level >= alarm ? Theme.red : hue

    implicitHeight: Theme.px(94)
    radius: Theme.radius
    color: Theme.alpha(Theme.surface0, 0.55)
    border.width: 1
    border.color: Theme.border

    Ring {
        id: ring

        x: Theme.px(12)
        y: Theme.px(10)
        implicitWidth: Theme.px(44)
        implicitHeight: Theme.px(44)
        thickness: 4.5
        value: Math.max(0, tile.level)
        color: tile.shade
        trackColor: Theme.alpha(tile.shade, 0.18)

        Icon {
            anchors.centerIn: parent
            text: tile.icon
            size: 17
            color: tile.shade
        }
    }

    Column {
        anchors.left: ring.right
        anchors.right: aside.left
        anchors.leftMargin: Theme.px(12)
        anchors.rightMargin: aside.width > 0 ? Theme.px(8) : 0
        anchors.verticalCenter: ring.verticalCenter

        Txt {
            width: parent.width
            text: tile.title
            size: 10
            color: Theme.dim
        }

        Txt {
            width: parent.width
            visible: text !== ""
            text: tile.value
            size: 18
            bold: true
        }

        Txt {
            width: parent.width
            visible: text !== ""
            text: tile.detail
            size: 10
            color: Theme.subtext
        }
    }

    Item {
        id: aside

        anchors.right: parent.right
        anchors.rightMargin: Theme.px(12)
        anchors.verticalCenter: ring.verticalCenter
        width: childrenRect.width
        height: childrenRect.height
    }

    Repeater {
        // By count, so the graphs are kept when new samples replace `series`.
        model: tile.series.length

        Sparkline {
            required property int index
            readonly property var entry: tile.series[index] ?? ({ values: [], color: tile.hue })

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: Theme.px(28)
            values: entry.values
            color: entry.color
            ceiling: tile.ceiling
            // Overlapping fills would hide the lines of the other series.
            filled: tile.series.length === 1
        }
    }
}
