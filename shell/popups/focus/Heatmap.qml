import QtQuick
import qs.core
import qs.widgets

// The week of the selected day, hour by hour: one row per weekday, one cell
// per hour, darker with more screen time. Clicking a row selects that day.
ChartCard {
    id: root

    property var stats: null
    readonly property var hours: stats?.heatmap ?? []
    readonly property var days: stats?.week ?? []
    readonly property int selectedDay: days.findIndex(day => day.selected)
    // The darkest cell is the busiest hour — but at least twenty minutes, so
    // that an application used for moments does not paint the map solid.
    readonly property real peak: Math.max(1200, ...hours.map(day => Math.max(...day)))
    // First hour of the two consecutive hours with the most screen time over the week, or -1.
    readonly property int busiestHour: {
        let best = -1, most = 0;
        for (let hour = 0; hour < 23; hour++) {
            let sum = 0;
            for (const day of hours)
                sum += day[hour] + day[hour + 1];
            if (sum > most) {
                most = sum;
                best = hour;
            }
        }
        return best;
    }
    // The cell under the pointer (or -1).
    property int hoveredDay: -1
    property int hoveredHour: -1
    readonly property bool hovering: hoveredDay >= 0 && hoveredDay < days.length

    signal daySelected(string date)

    function hourTime(hour) {
        return (hour < 10 ? "0" : "") + hour + ":00";
    }

    title: "Week by hour"
    note: hovering ? days[hoveredDay].day + " " + hourTime(hoveredHour) + " · " + Fmt.duration(hours[hoveredDay]?.[hoveredHour] ?? 0) : busiestHour >= 0 ? "busiest " + hourTime(busiestHour) + " – " + hourTime(busiestHour + 2) : ""

    Item {
        id: plot

        readonly property real labelWidth: Theme.px(40)
        readonly property real axisHeight: Theme.px(18)
        readonly property real gap: Math.max(2, Theme.px(2))
        readonly property real cellWidth: (width - labelWidth) / 24
        readonly property real cellHeight: (height - axisHeight) / 7

        anchors.fill: parent

        Stretch {
            vertical: true
            width: plot.labelWidth - Theme.px(6)
            color: Theme.alpha(Theme.accent, 0.18)
            visible: root.selectedDay >= 0
            targetStart: root.selectedDay * plot.cellHeight + plot.gap / 2
            targetEnd: (root.selectedDay + 1) * plot.cellHeight - plot.gap / 2
        }

        Repeater {
            model: 7

            Txt {
                required property int index
                readonly property bool isSelected: index === root.selectedDay

                x: Theme.px(6)
                y: index * plot.cellHeight
                height: plot.cellHeight
                text: root.days[index]?.day ?? ""
                size: 10
                bold: isSelected
                color: isSelected ? Theme.text : Theme.dim
            }
        }

        Item {
            id: cells

            x: plot.labelWidth
            width: parent.width - x
            height: parent.height - plot.axisHeight

            Repeater {
                model: 7 * 24

                Rectangle {
                    required property int index
                    readonly property real seconds: root.hours[Math.floor(index / 24)]?.[index % 24] ?? 0

                    x: Math.round((index % 24) * plot.cellWidth + plot.gap / 2)
                    y: Math.round(Math.floor(index / 24) * plot.cellHeight + plot.gap / 2)
                    width: Math.round(plot.cellWidth - plot.gap)
                    height: Math.round(plot.cellHeight - plot.gap)
                    radius: Theme.px(3)
                    color: seconds > 0 ? Theme.alpha(Theme.accent, 0.14 + 0.86 * Math.min(1, seconds / root.peak)) : Theme.alpha(Theme.surface2, 0.32)

                    Behavior on color {
                        ColorAnimation { duration: Theme.slow }
                    }
                }
            }

            // One outline that follows the pointer, rather than hover state in every cell.
            Rectangle {
                visible: root.hovering
                x: Math.round(root.hoveredHour * plot.cellWidth)
                y: Math.round(root.hoveredDay * plot.cellHeight)
                width: Math.round(plot.cellWidth)
                height: Math.round(plot.cellHeight)
                radius: Theme.px(4)
                color: "transparent"
                border.width: 1
                border.color: Theme.alpha(Theme.text, 0.7)
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: root.days[root.hoveredDay]?.date <= root.stats?.today ? Qt.PointingHandCursor : Qt.ArrowCursor
                onPositionChanged: mouse => {
                    root.hoveredHour = Math.max(0, Math.min(23, Math.floor(mouse.x / plot.cellWidth)));
                    root.hoveredDay = Math.max(0, Math.min(6, Math.floor(mouse.y / plot.cellHeight)));
                }
                onExited: root.hoveredDay = -1
                onClicked: {
                    const day = root.days[root.hoveredDay];
                    if (day && day.date <= root.stats.today)
                        root.daySelected(day.date);
                }
            }
        }

        HourAxis {
            anchors.left: cells.left
            anchors.right: cells.right
            anchors.bottom: parent.bottom
        }
    }
}
