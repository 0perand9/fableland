import QtQuick
import qs.core
import qs.widgets

// The selected day in 48 half-hour bars.
ChartCard {
    id: root

    property var stats: null
    readonly property var slots: stats?.halfHours ?? []
    // A full bar is the busiest half hour — but at least ten minutes, so that
    // an application used for moments does not fill the chart.
    readonly property real peak: Math.max(600, ...slots)
    // The half hour under the pointer, or -1.
    property int hovered: -1

    // 0 → "00:00", 29 → "14:30"
    function slotTime(slot) {
        const hour = Math.floor(slot / 2);
        return (hour < 10 ? "0" : "") + hour + (slot % 2 === 1 ? ":30" : ":00");
    }

    title: "Through the day"
    note: hovered >= 0 ? slotTime(hovered) + " – " + slotTime(hovered + 1) + " · " + Fmt.duration(slots[hovered] ?? 0) : "per half hour"

    Item {
        id: plot

        readonly property real pitch: width / 48
        readonly property real gap: Math.max(2, Theme.px(2))
        readonly property real axisHeight: Theme.px(18)
        readonly property real barSpace: height - axisHeight

        anchors.fill: parent

        Repeater {
            model: 48

            Rectangle {
                required property int index
                readonly property real seconds: root.slots[index] ?? 0

                x: Math.round(index * plot.pitch + plot.gap / 2)
                y: plot.barSpace - height
                width: Math.round(plot.pitch - plot.gap)
                height: seconds > 0 ? Math.max(Theme.px(3), plot.barSpace * seconds / root.peak) : Theme.px(3)
                topLeftRadius: Theme.px(3)
                topRightRadius: Theme.px(3)
                color: seconds === 0 ? Theme.alpha(Theme.surface2, 0.5) : Theme.alpha(Theme.accent, index === root.hovered ? 1 : 0.7)

                Behavior on height {
                    NumberAnimation { duration: Theme.slow; easing.type: Easing.OutCubic }
                }
            }
        }

        HourAxis {
            anchors.bottom: parent.bottom
            width: parent.width
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onPositionChanged: mouse => root.hovered = Math.max(0, Math.min(47, Math.floor(mouse.x / plot.pitch)))
            onExited: root.hovered = -1
        }
    }
}
