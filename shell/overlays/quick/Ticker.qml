import QtQuick
import qs.core

// The present moment in milliseconds, for displays worked out from the
// daemon's end and start times. It ticks only while `running`, and catches up
// whenever the timers change — a fresh timestamp only means something
// against a fresh "now".
Item {
    id: root

    property bool running: false
    property int interval: 250
    property real now: Date.now()

    visible: false

    Timer {
        interval: root.interval
        repeat: true
        running: root.running
        triggeredOnStart: true
        onTriggered: root.now = Date.now()
    }

    Connections {
        target: Daemon

        function onTimersChanged() {
            root.now = Date.now();
        }
    }
}
