import QtQuick
import qs.core
import qs.widgets

// The headline: the day's total, counted up, and what it is measured against —
// the day before and the week's daily average.
Card {
    id: root

    // `focus.stats` of what is shown: the whole day, or one application's part of it.
    property var stats: null
    property string caption: ""
    // A remark at the right of the caption, e.g. the application's share of the day.
    property string remark: ""
    // What the day before the selected one is called.
    property string previousLabel: ""

    readonly property real total: stats?.total ?? 0
    property real counted: total

    Behavior on counted {
        NumberAnimation { duration: 2 * Theme.slow; easing.type: Easing.OutCubic }
    }

    Txt {
        id: captionText

        anchors.left: parent.left
        anchors.right: remarkText.left
        anchors.leftMargin: Theme.pad
        anchors.rightMargin: Theme.gap
        y: Theme.px(14)
        text: root.caption
        size: 12
        bold: true
        color: Theme.subtext
    }

    Txt {
        id: remarkText

        anchors.right: parent.right
        anchors.rightMargin: Theme.pad
        anchors.verticalCenter: captionText.verticalCenter
        text: root.remark
        size: 11
        color: Theme.dim
    }

    Txt {
        id: figure

        anchors.left: parent.left
        anchors.leftMargin: Theme.pad
        anchors.top: captionText.bottom
        anchors.topMargin: Theme.px(2)
        text: Fmt.duration(root.counted)
        size: 40
        bold: true
    }

    Row {
        id: comparisons

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Theme.px(12)
        spacing: Theme.gap

        Comparison {
            width: (comparisons.width - comparisons.spacing) / 2
            label: root.previousLabel
            reference: root.stats?.yesterday ?? 0
            total: root.total
        }

        Comparison {
            width: (comparisons.width - comparisons.spacing) / 2
            label: "Daily average"
            reference: root.stats?.average ?? 0
            total: root.total
        }
    }
}
