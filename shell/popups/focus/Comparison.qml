import QtQuick
import qs.core
import qs.widgets

// A figure the day's total is measured against, and the difference to it.
// Less screen time than the reference is the good direction.
Rectangle {
    id: root

    property string label: ""
    property real reference: 0                  // seconds
    property real total: 0                      // seconds
    readonly property real difference: total - reference
    // Differences below a minute are noise.
    readonly property bool same: Math.abs(difference) < 60

    implicitHeight: Theme.px(66)
    radius: Theme.radiusSmall
    color: Theme.alpha(Theme.surface1, 0.45)

    Column {
        x: Theme.px(12)
        width: parent.width - 2 * x
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.px(1)

        Txt {
            width: parent.width
            text: root.label
            size: 10
            color: Theme.dim
        }

        Txt {
            width: parent.width
            text: root.reference > 0 ? Fmt.duration(root.reference) : "–"
            size: 14
            bold: true
        }

        Row {
            spacing: Theme.px(3)

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                visible: !root.same
                text: root.difference > 0 ? Icons.arrowUp : Icons.arrowDown
                size: 12
                color: root.difference > 0 ? Theme.yellow : Theme.green
            }

            Txt {
                anchors.verticalCenter: parent.verticalCenter
                text: root.same ? (root.total > 0 ? "about the same" : "no data") : Fmt.duration(Math.abs(root.difference)) + (root.difference > 0 ? " more" : " less")
                size: 11
                color: Theme.subtext
            }
        }
    }
}
