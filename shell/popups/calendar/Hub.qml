import QtQuick
import QtQuick.Shapes
import qs.core
import qs.widgets

// The centre of the calendar: the clock and, circling it, the hours of one
// forecast day as pills on a tilted orbit.
//
// Today's hours fan out around the current one, which sits up front; the hours
// of another day circle slowly. Switching days spins the old hours away and
// the new ones in from the other side.
Item {
    id: hub

    required property date now
    required property string todayKey
    // The forecast day to show: an entry of `weather.days`, or null without a forecast.
    property var day: null

    // The day whose hours are on the orbit. It follows `day` half-way through the hand-over.
    property var shown: null
    readonly property bool fanned: !!shown && shown.date === todayKey
    readonly property int hour: now.getHours()
    // Today's forecast hour nearest to now.
    readonly property int currentIndex: {
        const hourly = shown?.hourly ?? [];
        let nearest = 0;
        for (let i = 1; i < hourly.length; i++)
            if (Math.abs(hourly[i].hour - hour) < Math.abs(hourly[nearest].hour - hour))
                nearest = i;
        return nearest;
    }

    // The orbit is a circle seen at a slant: these are its half-axes.
    readonly property real orbitX: Theme.px(315)
    readonly property real orbitY: Theme.px(138)
    // Degrees: one slow revolution a minute. Everything that drifts derives from it.
    property real turn: 0
    readonly property real breath: 1.017 + 0.017 * sway(9, 0)

    // The hand-over between days: how far the orbit is spun away, how much of it is there, which way it goes.
    property real spin: 0
    property real presence: 1
    property int direction: 1

    // A slow sine with `cycles` whole periods per revolution, so nothing jumps when `turn` wraps around.
    function sway(cycles, shift) {
        return Math.sin(turn * cycles * Math.PI / 180 + shift);
    }

    onDayChanged: {
        // Nothing to hand over: the first forecast, no forecast, or fresher data for the same day.
        if (!shown || !day || shown.date === day.date) {
            shown = day;
            return;
        }
        direction = day.date > shown.date ? 1 : -1;
        handOver.restart();
    }
    Component.onCompleted: shown = day

    NumberAnimation on turn {
        from: 0
        to: 360
        duration: 60000
        loops: Animation.Infinite
        running: hub.visible
    }

    SequentialAnimation {
        id: handOver

        ParallelAnimation {
            NumberAnimation { target: hub; property: "spin"; to: 180 * hub.direction; duration: 200; easing.type: Easing.InCubic }
            NumberAnimation { target: hub; property: "presence"; to: 0; duration: 180; easing.type: Easing.InSine }
        }
        ScriptAction {
            script: {
                hub.shown = hub.day;
                hub.spin = -180 * hub.direction;
            }
        }
        ParallelAnimation {
            NumberAnimation { target: hub; property: "spin"; to: 0; duration: 520; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
            NumberAnimation { target: hub; property: "presence"; to: 1; duration: 380; easing.type: Easing.OutCubic }
        }
    }

    KeyedModel {
        id: hours

        source: hub.shown?.hourly ?? []
        key: "at"
    }

    // The day's weather, huge and faint, behind everything.
    Icon {
        anchors.centerIn: parent
        text: Icons.weather(hub.shown?.condition ?? "")
        size: 520
        color: Theme.weatherColor(hub.shown?.condition ?? "")
        opacity: hub.shown ? 0.03 * hub.presence : 0
    }

    // Everything on and inside the orbit, laid out around its centre. It
    // floats: up and down a little, and tilting slightly in all three axes.
    Item {
        id: space

        x: hub.width / 2
        y: hub.height / 2 + Theme.px(7) * (hub.sway(8, 1) - 1)
        transform: [
            Rotation { axis { x: 1; y: 0; z: 0 } angle: 3.5 * hub.sway(7, 0) },
            Rotation { axis { x: 0; y: 1; z: 0 } angle: 2.5 * hub.sway(6, 2) },
            Rotation { axis { x: 0; y: 0; z: 1 } angle: 1.5 * hub.sway(5, 4) }
        ]

        Shape {
            x: -hub.orbitX
            y: -hub.orbitY
            width: 2 * hub.orbitX
            height: 2 * hub.orbitY
            scale: hub.breath
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: Theme.alpha(Theme.text, 0.2)
                strokeWidth: Math.max(1, Theme.px(1.5))
                fillColor: "transparent"
                strokeStyle: ShapePath.DashLine
                dashPattern: [3, 6]

                PathAngleArc {
                    centerX: hub.orbitX
                    centerY: hub.orbitY
                    radiusX: hub.orbitX
                    radiusY: hub.orbitY
                    startAngle: 0
                    sweepAngle: 360
                }
            }
        }

        Column {
            x: -width / 2
            y: -height / 2

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.px(2)

                Txt {
                    id: hoursAndMinutes

                    text: Qt.formatTime(hub.now, "HH:mm")
                    size: 84
                    font.weight: Font.Black
                }

                Txt {
                    anchors.baseline: hoursAndMinutes.baseline
                    text: Qt.formatTime(hub.now, ":ss")
                    size: 32
                    bold: true
                    color: Theme.blue
                    // Every second lights up, then dims.
                    onTextChanged: tick.restart()

                    NumberAnimation on opacity {
                        id: tick

                        from: 1
                        to: 0.55
                        duration: 800
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Txt {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDate(hub.now, "dddd, MMMM d")
                size: 16
                bold: true
                color: Theme.subtext
            }
        }

        Item {
            opacity: hub.presence
            scale: 0.8 + 0.2 * hub.presence

            Repeater {
                model: hours.rows

                HourPill {
                    required property string key
                    required property int index
                    readonly property var slot: hours.byKey[key] ?? ({})
                    // Where on the orbit, in degrees: 90 is up front, 270 at the back. Later hours lie to
                    // the right, so the front reads like a timeline; a full day starts with noon up front.
                    readonly property real angle: hub.spin + (hub.fanned ? 115 - (index - hub.currentIndex) * 30 + 5 * hub.sway(6, index) : 90 + (hours.count / 2 - index) * 360 / hours.count + hub.turn)
                    readonly property real depth: Math.sin(angle * Math.PI / 180)
                    // 0 … 1 while the pointer rests on the pill: it comes forward to be read.
                    property real lift: hovered ? 1 : 0

                    x: Math.cos(angle * Math.PI / 180) * hub.orbitX * hub.breath - width / 2
                    y: depth * hub.orbitY * hub.breath - height / 2
                    z: hovered ? 2 : depth
                    scale: current ? 1.35 : (0.93 + 0.22 * depth) * (1 - lift) + 1.15 * lift
                    opacity: current ? 1 : (0.68 + 0.16 * (depth + 1)) * (1 - lift) + lift
                    time: slot.time ?? ""
                    condition: slot.condition ?? ""
                    temperature: slot.temp ?? 0
                    current: hub.fanned && index === hub.currentIndex

                    Behavior on lift {
                        NumberAnimation { duration: Theme.fast }
                    }
                }
            }
        }
    }
}
