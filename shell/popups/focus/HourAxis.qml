import QtQuick
import qs.core
import qs.widgets

// The time axis under a chart that spans a day: 00:00 · 06:00 · 12:00 · 18:00 ·
// 24:00, each centred on its place (the outer two stay inside the chart).
Item {
    id: root

    implicitHeight: Theme.px(12)

    Repeater {
        model: 5

        Txt {
            required property int index

            x: Math.max(0, Math.min(root.width - width, index * root.width / 4 - width / 2))
            anchors.bottom: parent.bottom
            text: (index * 6 < 10 ? "0" : "") + index * 6 + ":00"
            size: 9
            color: Theme.dim
        }
    }
}
