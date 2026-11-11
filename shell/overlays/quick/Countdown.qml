import QtQuick
import qs.core
import qs.widgets

// The countdown timer. While it is idle its duration can be chosen — a preset,
// or hours, minutes and seconds one by one; started, it drains the ring.
FocusScope {
    id: view

    readonly property var timer: Daemon.timers.timer
    // Neither running nor paused half-way: the duration is being chosen.
    readonly property bool idle: !timer.running && timer.remainingMs === timer.presetMs
    readonly property real remaining: timer.running ? Math.max(0, timer.endsAt - clock.now) : timer.remainingMs

    // Hours, minutes, seconds: their length and how far each counts.
    readonly property var units: [{ ms: 3600000, wrap: 100 }, { ms: 60000, wrap: 60 }, { ms: 1000, wrap: 60 }]
    // The unit the arrow keys change.
    property int unit: 1
    readonly property var presetMinutes: [1, 5, 10, 15, 30, 60]

    function toggle() {
        Daemon.send(timer.running ? "timers.timerPause" : "timers.timerStart");
    }

    function set(ms) {
        Daemon.send("timers.timerSet", { ms: Math.max(0, ms) });
    }

    function nudge(unit, steps) {
        if (idle)
            set(timer.presetMs + units[unit].ms * steps);
    }

    // Back to the chosen duration — or, already there, down to zero to start afresh.
    function reset() {
        if (idle)
            set(0);
        else
            Daemon.send("timers.timerReset");
    }

    focus: true
    Keys.onPressed: event => {
        switch (event.key) {
        case Qt.Key_Space:
        case Qt.Key_Return:
        case Qt.Key_Enter:
            toggle();
            break;
        case Qt.Key_Left:
            unit = Math.max(0, unit - 1);
            break;
        case Qt.Key_Right:
            unit = Math.min(units.length - 1, unit + 1);
            break;
        case Qt.Key_Up:
            nudge(unit, 1);
            break;
        case Qt.Key_Down:
            nudge(unit, -1);
            break;
        default:
            return;
        }
        event.accepted = true;
    }

    Ticker {
        id: clock

        running: view.visible && view.timer.running
    }

    Ring {
        id: ring

        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.px(4)
        implicitWidth: Theme.px(196)
        implicitHeight: Theme.px(196)
        thickness: 8
        value: view.idle || view.timer.presetMs <= 0 ? 1 : view.remaining / view.timer.presetMs
        color: Theme.alpha(Theme.accent, view.idle ? 0.4 : 1)
        trackColor: Theme.alpha(Theme.accent, 0.14)

        // Choosing the duration.
        Row {
            anchors.centerIn: parent
            visible: view.idle

            Repeater {
                model: view.units

                Row {
                    id: field

                    required property var modelData
                    required property int index
                    readonly property bool chosen: index === view.unit
                    readonly property int amount: Math.floor(view.timer.presetMs / modelData.ms) % modelData.wrap

                    Txt {
                        visible: field.index > 0
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.px(12)
                        horizontalAlignment: Text.AlignHCenter
                        text: ":"
                        size: 28
                        bold: true
                        color: Theme.dim
                    }

                    Item {
                        width: digits.width
                        height: digits.height

                        // Behind the arrows: a click on the figures picks the unit, the wheel changes it.
                        MouseArea {
                            anchors.fill: parent
                            onClicked: view.unit = field.index
                            onWheel: wheel => view.nudge(field.index, wheel.angleDelta.y > 0 ? 1 : -1)
                        }

                        Column {
                            id: digits

                            IconBtn {
                                anchors.horizontalCenter: parent.horizontalCenter
                                icon: Icons.chevronUp
                                size: 24
                                iconSize: 18
                                iconColor: field.chosen ? Theme.accent : Theme.dim
                                onClicked: {
                                    view.unit = field.index;
                                    view.nudge(field.index, 1);
                                }
                            }

                            Txt {
                                width: Theme.px(44)
                                horizontalAlignment: Text.AlignHCenter
                                text: String(field.amount).padStart(2, "0")
                                size: 30
                                bold: true
                                color: field.chosen ? Theme.accent : Theme.text
                            }

                            IconBtn {
                                anchors.horizontalCenter: parent.horizontalCenter
                                icon: Icons.chevronDown
                                size: 24
                                iconSize: 18
                                iconColor: field.chosen ? Theme.accent : Theme.dim
                                onClicked: {
                                    view.unit = field.index;
                                    view.nudge(field.index, -1);
                                }
                            }
                        }
                    }
                }
            }
        }

        // Counting down, or paused on the way.
        Column {
            anchors.centerIn: parent
            visible: !view.idle
            spacing: Theme.px(2)

            Txt {
                anchors.horizontalCenter: parent.horizontalCenter
                // Whole seconds still to go, so it shows 0:00 only when it is over.
                text: Fmt.clock(Math.ceil(view.remaining / 1000))
                size: 38
                bold: true
            }

            Txt {
                anchors.horizontalCenter: parent.horizontalCenter
                text: view.timer.running ? "until " + Qt.formatTime(new Date(view.timer.endsAt), "hh:mm") : "paused"
                size: 11
                color: Theme.subtext
            }
        }
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: ring.bottom
        anchors.topMargin: Theme.px(16)
        spacing: Theme.px(6)

        Repeater {
            model: view.presetMinutes

            Clickable {
                id: preset

                required property int modelData
                readonly property bool chosen: view.timer.presetMs === modelData * 60000

                width: Theme.px(50)
                height: Theme.px(30)
                radius: height / 2
                fill: chosen ? Theme.alpha(Theme.accent, 0.18) : Theme.alpha(Theme.surface1, 0.6)
                border.width: 1
                border.color: chosen ? Theme.alpha(Theme.accent, 0.5) : Theme.border
                // Choosing another duration would throw a running countdown away.
                interactive: !view.timer.running
                opacity: interactive ? 1 : 0.45
                onClicked: view.set(modelData * 60000)

                Txt {
                    anchors.centerIn: parent
                    text: preset.modelData < 60 ? preset.modelData + "m" : preset.modelData / 60 + "h"
                    size: 12
                    bold: true
                    color: preset.chosen ? Theme.accent : Theme.subtext
                }
            }
        }
    }

    TimerControls {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        running: view.timer.running
        startable: view.timer.remainingMs > 0
        leftIcon: Icons.restart
        onToggled: view.toggle()
        onLeftClicked: view.reset()
    }
}
