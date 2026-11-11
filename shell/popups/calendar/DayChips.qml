import QtQuick
import qs.core
import qs.widgets

// The daily forecast: one chip per day, with the travelling highlight on the
// day that is on show. Like Tabs it does not select by itself.
Rectangle {
    id: chips

    // `weather.days`
    property var days: []
    property int current: 0
    property string todayKey: ""

    signal selected(int index)

    readonly property real inset: Theme.px(4)
    readonly property real chipWidth: (width - 2 * inset) / Math.max(1, entries.count)

    implicitHeight: Theme.px(104)
    radius: Theme.radius
    color: Theme.alpha(Theme.surface0, 0.55)
    border.width: 1
    border.color: Theme.border

    KeyedModel {
        id: entries

        source: chips.days
        key: "date"
    }

    Stretch {
        y: chips.inset
        height: chips.height - 2 * chips.inset
        radius: Theme.radiusSmall
        targetStart: chips.inset + chips.current * chips.chipWidth
        targetEnd: targetStart + chips.chipWidth
        visible: chips.current >= 0 && chips.current < entries.count
    }

    Repeater {
        model: entries.rows

        Item {
            id: chip

            required property string key
            required property int index
            readonly property var day: entries.byKey[key] ?? ({})
            readonly property bool isCurrent: index === chips.current
            readonly property color foreground: isCurrent ? Theme.accentText : hover.containsMouse ? Theme.text : Theme.subtext

            x: chips.inset + index * chips.chipWidth
            y: chips.inset
            width: chips.chipWidth
            height: chips.height - 2 * chips.inset

            Column {
                anchors.centerIn: parent
                spacing: Theme.px(2)

                Txt {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: chip.key === chips.todayKey ? "Today" : (chip.day.day ?? "")
                    size: 11
                    bold: true
                    color: chip.foreground

                    Behavior on color {
                        ColorAnimation { duration: Theme.normal }
                    }
                }

                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Icons.weather(chip.day.condition ?? "")
                    size: 21
                    color: chip.isCurrent ? Theme.accentText : Theme.weatherColor(chip.day.condition ?? "")

                    Behavior on color {
                        ColorAnimation { duration: Theme.normal }
                    }
                }

                Txt {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Math.round(chip.day.max ?? 0) + "°"
                    size: 13
                    bold: true
                    color: chip.isCurrent ? Theme.accentText : Theme.text
                }

                Txt {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Math.round(chip.day.min ?? 0) + "°"
                    size: 10
                    color: chip.isCurrent ? Theme.alpha(Theme.accentText, 0.7) : Theme.dim
                }
            }

            MouseArea {
                id: hover

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: chips.selected(chip.index)
            }
        }
    }
}
