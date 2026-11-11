import QtQuick
import qs.core
import qs.widgets

// The week of the selected day as bars, with the daily average as a line.
// Clicking a day selects it.
ChartCard {
    id: root

    property var stats: null
    readonly property var days: stats?.week ?? []
    readonly property real peak: Math.max(1, ...days.map(day => day.total))
    readonly property int selectedIndex: days.findIndex(day => day.selected)
    property int hovered: -1

    signal daySelected(string date)

    title: "Week"
    note: days[hovered] ? days[hovered].day + " · " + Fmt.duration(days[hovered].total) : (stats?.weekRange ?? "").replace(" - ", " – ")

    Item {
        id: plot

        // The strip right of the bars where the average line is named.
        readonly property real gutter: Theme.px(24)
        readonly property real slot: (width - gutter) / 7
        readonly property real labelHeight: Theme.px(20)
        readonly property real barSpace: height - labelHeight - Theme.px(4)
        readonly property real axisY: height - labelHeight

        anchors.fill: parent

        Stretch {
            height: parent.height
            radius: Theme.radiusSmall
            color: Theme.alpha(Theme.accent, 0.12)
            visible: root.selectedIndex >= 0
            targetStart: root.selectedIndex * plot.slot + Theme.px(2)
            targetEnd: (root.selectedIndex + 1) * plot.slot - Theme.px(2)
        }

        Repeater {
            model: 7

            Item {
                id: column

                required property int index
                readonly property var day: root.days[index] ?? null
                readonly property real total: day?.total ?? 0
                readonly property bool isSelected: day?.selected ?? false
                readonly property bool future: !!day && day.date > root.stats.today

                x: index * plot.slot
                width: plot.slot
                height: plot.height

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: plot.axisY - height
                    width: Math.min(Theme.px(24), Math.round(parent.width * 0.6))
                    height: column.total > 0 ? Math.max(Theme.px(3), plot.barSpace * column.total / root.peak) : Theme.px(3)
                    topLeftRadius: Theme.px(4)
                    topRightRadius: Theme.px(4)
                    color: column.total === 0 ? Theme.alpha(Theme.surface2, 0.5) : column.isSelected ? Theme.accent : Theme.alpha(Theme.accent, root.hovered === column.index ? 0.65 : 0.38)

                    Behavior on height {
                        NumberAnimation { duration: Theme.slow; easing.type: Easing.OutCubic }
                    }
                    Behavior on color {
                        ColorAnimation { duration: Theme.normal }
                    }
                }

                Txt {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Theme.px(2)
                    text: column.day?.day ?? ""
                    size: 11
                    bold: column.isSelected
                    color: column.isSelected ? Theme.text : column.future ? Theme.faint : Theme.dim
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: !!column.day && !column.future
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.hovered = column.index
                    onExited: {
                        if (root.hovered === column.index)
                            root.hovered = -1;
                    }
                    onClicked: root.daySelected(column.day.date)
                }
            }
        }

        // The daily average, across the bars and named in the gutter.
        Rectangle {
            readonly property real average: root.stats?.average ?? 0

            visible: average > 0
            y: Math.round(plot.axisY - plot.barSpace * Math.min(1, average / root.peak))
            width: parent.width
            height: 1
            color: Theme.alpha(Theme.text, 0.28)

            Behavior on y {
                NumberAnimation { duration: Theme.slow; easing.type: Easing.OutCubic }
            }

            Txt {
                anchors.right: parent.right
                anchors.bottom: parent.top
                text: "avg"
                size: 9
                color: Theme.dim
            }
        }
    }
}
