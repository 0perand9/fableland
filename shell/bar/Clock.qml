import QtQuick
import Quickshell
import qs.core
import qs.widgets

// Time, date and the weather. Clicking it opens the calendar.
BarGroup {
    id: root

    required property var screen

    readonly property var current: Daemon.weather.current
    readonly property string dateText: Qt.formatDate(clock.date, "dddd, MMMM dd")
    // The date is typed out when the bar appears.
    property int typed: 0

    padding: Theme.px(6)

    SystemClock {
        id: clock

        precision: SystemClock.Seconds
    }

    Timer {
        interval: 45
        repeat: true
        running: root.typed < root.dateText.length
        onTriggered: root.typed++
    }

    Clickable {
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: row.implicitWidth + Theme.px(24)
        implicitHeight: Theme.px(36)
        onClicked: Ui.toggle("calendar", "", root.screen)

        Row {
            id: row

            anchors.centerIn: parent
            spacing: Theme.px(14)

            Column {
                anchors.verticalCenter: parent.verticalCenter

                Txt {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatTime(clock.date, "HH:mm:ss")
                    size: 15
                    bold: true
                    color: Theme.blue
                }

                Txt {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.dateText.slice(0, root.typed)
                    size: 10
                    color: Theme.subtext
                }
            }

            Rectangle {
                visible: weather.visible
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: Theme.px(20)
                color: Theme.alpha(Theme.text, 0.12)
            }

            Row {
                id: weather

                visible: !!root.current
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.px(8)

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Icons.weather(root.current?.condition ?? "")
                    size: 19
                    color: Theme.weatherColor(root.current?.condition ?? "")
                }

                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(root.current?.temp ?? 0) + Daemon.weather.tempUnit
                    size: 13
                    bold: true
                    color: Theme.peach
                }
            }
        }
    }
}
