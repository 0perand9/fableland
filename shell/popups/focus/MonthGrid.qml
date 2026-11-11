import QtQuick
import qs.core
import qs.widgets

// The month of the selected day as a calendar whose cells darken with screen
// time. Clicking a day selects it; the arrows move a month back or forth.
ChartCard {
    id: root

    property var stats: null
    readonly property var days: stats?.month ?? []
    // Weekday of the 1st (0 = Monday): the cells before it stay empty.
    readonly property int offset: stats?.monthOffset ?? 0
    readonly property int weeks: Math.max(4, Math.ceil((offset + days.length) / 7))
    readonly property real peak: Math.max(1, ...days.map(day => day.total))
    readonly property bool thisMonth: !stats || stats.date.slice(0, 7) === stats.today.slice(0, 7)
    // Index into `days` of the day under the pointer, or -1.
    property int hovered: -1

    signal daySelected(string date)
    signal monthShifted(int months)

    title: days[hovered] ? (hovered + 1) + " " + stats.monthName.slice(0, 3) + " · " + Fmt.duration(days[hovered].total) : (stats?.monthName ?? "")
    trailing: [
        IconBtn {
            icon: Icons.chevronLeft
            size: 24
            iconSize: 18
            iconColor: Theme.subtext
            onClicked: root.monthShifted(-1)
        },
        IconBtn {
            icon: Icons.chevronRight
            size: 24
            iconSize: 18
            iconColor: Theme.subtext
            interactive: !root.thisMonth
            onClicked: root.monthShifted(1)
        }
    ]

    Row {
        id: weekdays

        width: parent.width

        Repeater {
            model: 7

            Txt {
                required property int index

                width: weekdays.width / 7
                horizontalAlignment: Text.AlignHCenter
                text: (root.stats?.week[index]?.day ?? "").charAt(0)
                size: 9
                color: Theme.dim
            }
        }
    }

    Item {
        id: grid

        readonly property real gap: Theme.px(3)
        readonly property real cellWidth: (width - 6 * gap) / 7
        readonly property real cellHeight: (height - (root.weeks - 1) * gap) / root.weeks

        function dayAt(x, y) {
            const column = Math.floor(x / (cellWidth + gap)), row = Math.floor(y / (cellHeight + gap));
            const day = row * 7 + column - root.offset;
            return column >= 0 && column < 7 && day >= 0 && day < root.days.length ? day : -1;
        }

        anchors.top: weekdays.bottom
        anchors.topMargin: Theme.px(4)
        anchors.bottom: parent.bottom
        width: parent.width

        Repeater {
            model: 42

            Rectangle {
                id: cell

                required property int index
                readonly property int dayIndex: index - root.offset
                readonly property var day: root.days[dayIndex] ?? null
                readonly property real share: day ? day.total / root.peak : 0
                readonly property bool future: !!day && day.date > root.stats.today

                visible: !!day
                x: (index % 7) * (grid.cellWidth + grid.gap)
                y: Math.floor(index / 7) * (grid.cellHeight + grid.gap)
                width: grid.cellWidth
                height: grid.cellHeight
                radius: Theme.px(4)
                color: share > 0 ? Theme.alpha(Theme.accent, 0.16 + 0.84 * share) : Theme.alpha(Theme.surface2, future ? 0.14 : 0.36)
                border.width: day?.selected ? Theme.px(2) : dayIndex === root.hovered && !future ? 1 : 0
                border.color: day?.selected ? Theme.text : Theme.alpha(Theme.text, 0.5)

                Behavior on color {
                    ColorAnimation { duration: Theme.slow }
                }

                Txt {
                    anchors.centerIn: parent
                    text: cell.dayIndex + 1
                    size: 9
                    bold: cell.day?.selected ?? false
                    color: cell.share > 0.5 ? Theme.accentText : cell.future ? Theme.faint : Theme.subtext
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: root.days[root.hovered]?.date <= root.stats?.today ? Qt.PointingHandCursor : Qt.ArrowCursor
            onPositionChanged: mouse => root.hovered = grid.dayAt(mouse.x, mouse.y)
            onExited: root.hovered = -1
            onClicked: mouse => {
                const day = root.days[grid.dayAt(mouse.x, mouse.y)];
                if (day && day.date <= root.stats.today)
                    root.daySelected(day.date);
            }
        }
    }
}
