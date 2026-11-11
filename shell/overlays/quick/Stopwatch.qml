import QtQuick
import qs.core
import qs.widgets

// The stopwatch and its laps.
FocusScope {
    id: view

    readonly property var watch: Daemon.timers.stopwatch
    readonly property real elapsed: watch.running ? watch.elapsedMs + Math.max(0, clock.now - watch.startedAt) : watch.elapsedMs
    readonly property string reading: stamp(elapsed)
    // Laps numbered as they were taken, newest first.
    readonly property var laps: watch.laps.map((lap, i) => ({ n: i + 1, total: lap.total, diff: lap.diff })).reverse()
    // The fastest and the slowest lap stand out once there are laps to compare.
    readonly property real fastest: watch.laps.length > 1 ? Math.min(...watch.laps.map(lap => lap.diff)) : -1
    readonly property real slowest: watch.laps.length > 1 ? Math.max(...watch.laps.map(lap => lap.diff)) : -1

    // 83450 → "01:23.45"
    function stamp(ms) {
        const hundredths = Math.floor(ms / 10), seconds = Math.floor(hundredths / 100);
        const two = n => String(n).padStart(2, "0");
        const hours = Math.floor(seconds / 3600);
        return (hours > 0 ? hours + ":" : "") + two(Math.floor(seconds / 60) % 60) + ":" + two(seconds % 60) + "." + two(hundredths % 100);
    }

    function toggle() {
        Daemon.send(watch.running ? "timers.stopwatchPause" : "timers.stopwatchStart");
    }

    // One button: a lap while it runs, back to zero while it stands.
    function lapOrReset() {
        Daemon.send(watch.running ? "timers.stopwatchLap" : "timers.stopwatchReset");
    }

    focus: true
    Keys.onPressed: event => {
        switch (event.key) {
        case Qt.Key_Space:
        case Qt.Key_Return:
        case Qt.Key_Enter:
            toggle();
            break;
        case Qt.Key_L:
            lapOrReset();
            break;
        default:
            return;
        }
        event.accepted = true;
    }

    Ticker {
        id: clock

        running: view.visible && view.watch.running
        // The display shows hundredths of a second.
        interval: 50
    }

    KeyedModel {
        id: rows

        source: view.laps
        key: "n"
    }

    Row {
        id: display

        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.px(8)

        Txt {
            id: whole

            text: view.reading.slice(0, -3)
            size: 46
            bold: true
        }

        Txt {
            anchors.baseline: whole.baseline
            // As wide as its widest reading, so the digits before it stay put.
            width: Theme.px(46)
            text: view.reading.slice(-3)
            size: 24
            bold: true
            color: Theme.subtext
        }
    }

    Txt {
        anchors.centerIn: list
        visible: rows.count === 0
        text: view.watch.running ? "Laps you take are listed here" : "Ready"
        size: 12
        color: Theme.dim
    }

    List {
        id: list

        anchors.top: display.bottom
        anchors.bottom: controls.top
        anchors.topMargin: Theme.px(12)
        anchors.bottomMargin: Theme.px(14)
        width: parent.width
        spacing: Theme.px(4)
        model: rows.rows

        add: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.normal }
        }
        displaced: Transition {
            NumberAnimation { property: "y"; duration: Theme.normal; easing.type: Easing.OutCubic }
        }

        delegate: Rectangle {
            id: row

            required property string key
            readonly property var lap: rows.byKey[key] ?? ({ n: 0, total: 0, diff: 0 })

            width: list.width
            height: Theme.px(32)
            radius: Theme.radiusSmall
            color: Theme.alpha(Theme.surface0, 0.55)

            Txt {
                anchors.left: parent.left
                anchors.leftMargin: Theme.px(12)
                anchors.verticalCenter: parent.verticalCenter
                text: "Lap " + row.lap.n
                size: 12
                color: Theme.subtext
            }

            Txt {
                anchors.right: total.left
                anchors.rightMargin: Theme.px(16)
                anchors.verticalCenter: parent.verticalCenter
                text: "+" + view.stamp(row.lap.diff)
                size: 12
                color: row.lap.diff === view.fastest ? Theme.green : row.lap.diff === view.slowest ? Theme.red : Theme.dim
            }

            Txt {
                id: total

                anchors.right: parent.right
                anchors.rightMargin: Theme.px(12)
                anchors.verticalCenter: parent.verticalCenter
                text: view.stamp(row.lap.total)
                size: 12
                bold: true
            }
        }
    }

    TimerControls {
        id: controls

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        running: view.watch.running
        leftIcon: view.watch.running ? Icons.flag : Icons.restart
        onToggled: view.toggle()
        onLeftClicked: view.lapOrReset()
    }
}
