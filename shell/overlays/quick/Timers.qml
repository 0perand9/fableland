import QtQuick
import qs.core
import qs.widgets

// Countdown timer, stopwatch and pomodoro. The daemon owns them — they keep
// running, and ring, while this is closed; the views only display its state.
FocusScope {
    id: timers

    // `topic` is the view's part of Daemon.timers.
    readonly property var views: [
        { label: "Timer", file: "Countdown.qml", topic: "timer" },
        { label: "Stopwatch", file: "Stopwatch.qml", topic: "stopwatch" },
        { label: "Pomodoro", file: "Pomodoro.qml", topic: "pomodoro" }
    ]
    property int tab: 0

    // Open on whatever is running, or else has been left half-way.
    function busiest() {
        const all = Daemon.timers;
        const running = views.findIndex(view => all[view.topic].running);
        if (running >= 0)
            return running;
        if (all.stopwatch.elapsedMs > 0)
            return 1;
        if (all.pomodoro.session > 0 || all.pomodoro.phase !== "focus" || all.pomodoro.remainingMs < all.pomodoro.workMin * 60000)
            return 2;
        return 0;
    }

    implicitWidth: Theme.px(380)
    implicitHeight: Theme.px(430)
    // The keys go to the view that is showing.
    focus: true
    Component.onCompleted: tab = busiest()

    Tabs {
        id: tabs

        x: Theme.pad
        y: Theme.pad
        width: parent.width - 2 * x
        model: timers.views.map(view => view.label)
        current: timers.tab
        onSelected: index => timers.tab = index
    }

    Loader {
        anchors.top: tabs.bottom
        anchors.bottom: parent.bottom
        anchors.topMargin: Theme.px(12)
        anchors.bottomMargin: Theme.pad
        x: Theme.pad
        width: parent.width - 2 * x
        source: timers.views[timers.tab].file
        focus: true
    }
}
