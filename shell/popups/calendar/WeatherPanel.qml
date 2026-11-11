import QtQuick
import qs.core
import qs.widgets

// The weather wing: the conditions of the forecast day on show (measured right
// now, when that day is today), four figures as gauges and the days to choose from.
Item {
    id: panel

    // The `weather` topic.
    required property var weather
    required property string todayKey
    // The forecast day on show — an entry of `weather.days` and its position — or null without a forecast.
    property var day: null
    property int dayIndex: 0

    signal daySelected(int index)

    // Today shows what is measured right now, other days what is forecast.
    readonly property bool live: !!day && day.date === todayKey && !!weather.current
    readonly property var reading: live ? weather.current : (day ?? ({}))
    readonly property real temperature: (live ? reading.temp : reading.max) ?? 0
    readonly property color hue: Theme.weatherColor(reading.condition ?? "")
    readonly property string tempUnit: weather.tempUnit ?? "°C"
    // Kelvin has no degree sign.
    readonly property string degree: tempUnit.startsWith("°") ? "°" : ""

    // Where a temperature lies between −15 °C and 40 °C, whatever the unit.
    function warmth(value) {
        const celsius = tempUnit === "°F" ? (value - 32) / 1.8 : tempUnit === "K" ? value - 273.15 : value;
        return Math.max(0, Math.min(1, (celsius + 15) / 55));
    }

    WeatherNotice {
        anchors.centerIn: parent
        width: parent.width - Theme.px(40)
        visible: !panel.day
        // "ok" without a single day to show is a failure too.
        status: panel.weather.status === "ok" ? "error" : (panel.weather.status ?? "loading")
        error: panel.weather.error ?? ""
    }

    Item {
        anchors.fill: parent
        visible: !!panel.day

        Item {
            id: header

            width: parent.width
            height: Theme.px(44)

            Column {
                anchors.left: parent.left
                anchors.right: asOf.left
                anchors.rightMargin: Theme.px(8)
                anchors.verticalCenter: parent.verticalCenter

                Txt {
                    width: parent.width
                    text: panel.live ? "Right now" : (panel.day?.dayFull ?? "")
                    size: 18
                    bold: true
                }

                Txt {
                    width: parent.width
                    text: [panel.weather.city, panel.day?.label].filter(part => !!part).join(" · ")
                    size: 12
                    color: Theme.subtext
                }
            }

            Txt {
                id: asOf

                anchors.right: refresh.left
                anchors.rightMargin: Theme.px(4)
                anchors.verticalCenter: parent.verticalCenter
                visible: !!panel.weather.updated
                text: "as of " + Qt.formatTime(new Date((panel.weather.updated ?? 0) * 1000), "HH:mm")
                size: 10
                color: Theme.dim
            }

            IconBtn {
                id: refresh

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                icon: Icons.refresh
                size: 32
                iconColor: Theme.subtext
                onClicked: {
                    Daemon.send("weather.refresh");
                    twirl.restart();
                }

                // The daemon does not say when it is fetching, so the click at least shows it landed.
                RotationAnimation {
                    id: twirl

                    target: refresh
                    from: 0
                    to: 360
                    duration: 700
                    easing.type: Easing.OutCubic
                }
            }
        }

        Item {
            anchors.top: header.bottom
            anchors.bottom: gauges.top
            width: parent.width

            Icon {
                anchors.left: parent.left
                anchors.leftMargin: Theme.px(4)
                anchors.verticalCenter: conditions.verticalCenter
                text: Icons.weather(panel.reading.condition ?? "")
                size: 84
                color: panel.hue

                Behavior on color {
                    ColorAnimation { duration: Theme.slow }
                }
            }

            Column {
                id: conditions

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter

                Row {
                    anchors.right: parent.right
                    spacing: Theme.px(6)

                    Txt {
                        id: figure

                        // The number counts to a new temperature, glowing warm on the way up and cold on the way down.
                        readonly property int target: Math.round(panel.temperature)
                        property real shown: target

                        text: Math.round(shown)
                        size: 80
                        font.weight: Font.Black
                        color: !counting.running ? Theme.text : target > shown ? Theme.peach : Theme.sapphire

                        Behavior on shown {
                            NumberAnimation { id: counting; duration: 600; easing.type: Easing.OutQuart }
                        }
                        Behavior on color {
                            ColorAnimation { duration: Theme.normal }
                        }
                    }

                    Txt {
                        anchors.top: figure.top
                        anchors.topMargin: Theme.px(16)
                        text: panel.tempUnit
                        size: 24
                        bold: true
                        color: Theme.dim
                    }
                }

                Txt {
                    anchors.right: parent.right
                    text: panel.reading.desc ?? ""
                    size: 15
                    bold: true
                    color: panel.hue
                }

                Row {
                    anchors.right: parent.right
                    topPadding: Theme.px(4)
                    spacing: Theme.px(4)

                    Icon {
                        anchors.verticalCenter: high.verticalCenter
                        text: Icons.arrowUp
                        size: 12
                        color: Theme.dim
                    }

                    Txt {
                        id: high

                        rightPadding: Theme.px(8)
                        text: Math.round(panel.day?.max ?? 0) + panel.degree
                        size: 12
                        color: Theme.subtext
                    }

                    Icon {
                        anchors.verticalCenter: high.verticalCenter
                        text: Icons.arrowDown
                        size: 12
                        color: Theme.dim
                    }

                    Txt {
                        text: Math.round(panel.day?.min ?? 0) + panel.degree
                        size: 12
                        color: Theme.subtext
                    }
                }
            }
        }

        Row {
            id: gauges

            readonly property real slot: width / 4

            anchors.bottom: chips.top
            anchors.bottomMargin: Theme.px(22)
            width: parent.width

            Gauge {
                width: gauges.slot
                label: "Wind"
                icon: Icons.wind
                value: Math.round(panel.reading.wind ?? 0)
                unit: panel.weather.windUnit ?? ""
                // A full ring is a storm: 25 m/s, 56 mph.
                fill: (panel.reading.wind ?? 0) / (unit === "mph" ? 56 : 25)
                color: panel.hue
            }

            Gauge {
                width: gauges.slot
                label: "Humidity"
                icon: Icons.humidity
                value: Math.round(panel.reading.humidity ?? 0)
                unit: "%"
                fill: (panel.reading.humidity ?? 0) / 100
                color: panel.hue
            }

            Gauge {
                width: gauges.slot
                label: "Rain"
                icon: Icons.umbrella
                value: Math.round(panel.day?.pop ?? 0)
                unit: "%"
                fill: (panel.day?.pop ?? 0) / 100
                color: panel.hue
            }

            Gauge {
                width: gauges.slot
                label: "Feels"
                icon: Icons.thermometer
                value: Math.round(panel.reading.feels ?? 0) + panel.degree
                unit: panel.tempUnit.replace("°", "")
                fill: panel.warmth(panel.reading.feels ?? 0)
                color: panel.hue
            }
        }

        DayChips {
            id: chips

            anchors.bottom: parent.bottom
            width: parent.width
            days: panel.weather.days ?? []
            current: panel.dayIndex
            todayKey: panel.todayKey
            onSelected: index => panel.daySelected(index)
        }
    }
}
