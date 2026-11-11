import QtQuick
import qs.core
import qs.widgets

// The machine's battery — when it has one — and the batteries of wireless
// peripherals (mouse, controller, …). A desktop shows only the peripherals.
Card {
    id: root

    readonly property var battery: Daemon.power.battery
    readonly property var peripherals: Daemon.power.peripherals
    readonly property bool hasContent: battery.present || peripherals.length > 0

    // Red when nearly empty, yellow as a warning, green otherwise and while charging.
    function levelColor(percent, charging) {
        return charging || percent > 40 ? Theme.green : percent > 20 ? Theme.yellow : Theme.red;
    }

    function stateText(state) {
        switch (state) {
        case "charging": return "Charging";
        case "discharging": return "On battery";
        case "full": return "Fully charged";
        case "empty": return "Empty";
        case "pending-charge": return "Plugged in, not charging";
        case "pending-discharge": return "On battery";
        default: return "Battery";
        }
    }

    implicitHeight: content.implicitHeight + 2 * Theme.pad

    Column {
        id: content

        x: Theme.pad
        y: Theme.pad
        width: parent.width - 2 * x
        spacing: Theme.px(14)

        // ── the machine's own battery ──
        Row {
            id: main

            readonly property color hue: root.levelColor(root.battery.percent, root.battery.charging)
            // Seconds until full or empty, when the system knows.
            readonly property real remaining: (root.battery.charging ? root.battery.timeToFull : root.battery.timeToEmpty) ?? 0

            visible: root.battery.present
            width: parent.width
            spacing: Theme.px(18)

            Orb {
                id: orb

                width: Theme.px(92)
                height: width
                level: root.battery.percent / 100
                text: Math.round(root.battery.percent) + "%"
                size: 20
                color: main.hue
                pulsing: root.battery.charging && root.battery.state !== "full"
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - orb.width - parent.spacing
                spacing: Theme.px(3)

                Row {
                    spacing: Theme.px(6)

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.battery.charging ? Icons.plug : Icons.batteryLevel(root.battery.percent, false)
                        size: 17
                        color: main.hue
                    }

                    Txt {
                        text: root.stateText(root.battery.state)
                        size: 15
                        bold: true
                    }
                }

                Txt {
                    width: parent.width
                    text: main.remaining > 0 ? Fmt.duration(main.remaining) + (root.battery.charging ? " until full" : " left")
                        : root.battery.charging ? "Connected to power" : "Running on battery"
                    size: 12
                    color: Theme.subtext
                }
            }
        }

        // ── peripherals, two to a row ──
        Flow {
            id: gauges

            readonly property real cell: (width - spacing) / 2

            visible: root.peripherals.length > 0
            width: parent.width
            spacing: Theme.px(12)

            Repeater {
                // By index, so that a gauge stays in place when its numbers change.
                model: root.peripherals.length

                Row {
                    id: gauge

                    required property int index
                    readonly property var device: root.peripherals[index] ?? ({})
                    readonly property color hue: root.levelColor(device.percent ?? 0, !!device.charging)

                    width: gauges.cell
                    spacing: Theme.px(12)

                    Ring {
                        id: ring

                        width: Theme.px(44)
                        height: width
                        thickness: 4
                        value: (gauge.device.percent ?? 0) / 100
                        color: gauge.hue

                        Icon {
                            anchors.centerIn: parent
                            text: Icons.device(gauge.device.kind, Icons.battery)
                            size: 19
                            color: Theme.text
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - ring.width - parent.spacing

                        Txt {
                            width: parent.width
                            text: gauge.device.name ?? ""
                            size: 12
                            bold: true
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                        }

                        Row {
                            spacing: Theme.px(4)

                            Txt {
                                text: Math.round(gauge.device.percent ?? 0) + "%"
                                size: 11
                                color: gauge.hue
                            }

                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: !!gauge.device.charging
                                text: Icons.bolt
                                size: 12
                                color: gauge.hue
                            }
                        }
                    }
                }
            }
        }
    }
}
