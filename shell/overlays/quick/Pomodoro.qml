import QtQuick
import qs.core
import qs.widgets

// The pomodoro: focus sessions with a short break after each and a long one
// after every round. The daemon moves from phase to phase on its own.
FocusScope {
    id: view

    readonly property var pomodoro: Daemon.timers.pomodoro
    readonly property var phases: ({
        focus: { label: "Focus", hue: Theme.accent, minutes: pomodoro.workMin },
        short: { label: "Short break", hue: Theme.green, minutes: pomodoro.shortMin },
        long: { label: "Long break", hue: Theme.blue, minutes: pomodoro.longMin }
    })
    readonly property var phase: phases[pomodoro.phase] ?? phases.focus
    // What follows the current phase: a break after focus (the long one closes a round), focus after a break.
    readonly property var next: pomodoro.phase !== "focus" ? phases.focus : pomodoro.session + 1 >= pomodoro.sessions ? phases.long : phases.short
    readonly property real remaining: pomodoro.running ? Math.max(0, pomodoro.endsAt - clock.now) : pomodoro.remainingMs
    // The lengths and the number of sessions are being edited.
    property bool configuring: false

    function toggle() {
        configuring = false;
        Daemon.send(pomodoro.running ? "timers.pomodoroPause" : "timers.pomodoroStart");
    }

    function configure(key, value) {
        const change = {};
        change[key] = value;
        Daemon.send("timers.pomodoroConfig", change);
    }

    focus: true
    Keys.onPressed: event => {
        if (event.key !== Qt.Key_Space && event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter)
            return;
        toggle();
        event.accepted = true;
    }

    Ticker {
        id: clock

        running: view.visible && view.pomodoro.running
    }

    Ring {
        id: ring

        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.px(4)
        visible: !view.configuring
        implicitWidth: Theme.px(196)
        implicitHeight: Theme.px(196)
        thickness: 8
        value: view.remaining / (view.phase.minutes * 60000)
        color: view.phase.hue
        trackColor: Theme.alpha(view.phase.hue, 0.14)

        Column {
            anchors.centerIn: parent
            spacing: Theme.px(4)

            Txt {
                anchors.horizontalCenter: parent.horizontalCenter
                text: view.phase.label.toUpperCase()
                size: 11
                bold: true
                color: view.phase.hue
                font.letterSpacing: Theme.px(1)
            }

            Txt {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Fmt.clock(Math.ceil(view.remaining / 1000))
                size: 38
                bold: true
            }

            // One dot per focus session of the round: done, under way, to come.
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.px(6)

                Repeater {
                    model: view.pomodoro.sessions

                    Rectangle {
                        required property int index
                        // The long break closes the round: every session is behind us.
                        readonly property bool done: view.pomodoro.phase === "long" || index < view.pomodoro.session
                        readonly property bool underWay: !done && view.pomodoro.phase === "focus" && index === view.pomodoro.session

                        width: Theme.px(8)
                        height: width
                        radius: width / 2
                        color: done ? Theme.accent : "transparent"
                        border.width: done ? 0 : Math.max(1, Theme.px(1.5))
                        border.color: underWay ? Theme.accent : Theme.faint
                    }
                }
            }
        }
    }

    Txt {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: ring.bottom
        anchors.topMargin: Theme.px(16)
        visible: !view.configuring
        height: Theme.px(30)
        text: "Next: " + view.next.label.toLowerCase() + ", " + view.next.minutes + " min"
        size: 12
        color: Theme.subtext
    }

    Card {
        y: Theme.px(4)
        visible: view.configuring
        width: parent.width
        height: settings.implicitHeight + 2 * settings.y

        Column {
            id: settings

            x: Theme.pad
            y: Theme.px(14)
            width: parent.width - 2 * x
            spacing: Theme.px(8)

            Stepper {
                width: parent.width
                label: "Focus"
                value: view.pomodoro.workMin
                unit: " min"
                step: 5
                from: 5
                to: 120
                onMoved: value => view.configure("workMin", value)
            }

            Stepper {
                width: parent.width
                label: "Short break"
                value: view.pomodoro.shortMin
                unit: " min"
                to: 30
                onMoved: value => view.configure("shortMin", value)
            }

            Stepper {
                width: parent.width
                label: "Long break"
                value: view.pomodoro.longMin
                unit: " min"
                step: 5
                from: 5
                to: 90
                onMoved: value => view.configure("longMin", value)
            }

            Stepper {
                width: parent.width
                label: "Sessions per round"
                value: view.pomodoro.sessions
                to: 12
                onMoved: value => view.configure("sessions", value)
            }

            Btn {
                anchors.right: parent.right
                text: "Start over"
                icon: Icons.restart
                kind: "flat"
                onClicked: Daemon.send("timers.pomodoroReset")
            }
        }
    }

    TimerControls {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        running: view.pomodoro.running
        hue: view.phase.hue
        leftIcon: Icons.tune
        leftActive: view.configuring
        rightIcon: Icons.next
        onToggled: view.toggle()
        onLeftClicked: view.configuring = !view.configuring
        onRightClicked: Daemon.send("timers.pomodoroSkip")
    }
}
