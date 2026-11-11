import QtQuick
import qs.core
import qs.widgets

// What the focus popup looks at — a day and, optionally, one application — and
// the statistics for it (the shape of `focus.stats` in docs/PROTOCOL.md).
// Today's overall numbers tick in through the `focus` topic; other days and
// single applications are fetched with `focus.stats`.
QtObject {
    id: root

    // The day picked by the user as YYYY-MM-DD; "" follows today.
    property string chosenDay: ""
    // The application drilled into: its class ("" = all applications), name and icon.
    property string app: ""
    property string appName: ""
    property string appIcon: ""

    property var todayStats: null       // all applications, today
    property var dayStats: null         // all applications, on `chosenDay`
    property var appStats: null         // `app` alone, on the selected day
    // Why the last request failed ("" = it did not).
    property string error: ""

    readonly property string today: todayStats?.today ?? ""
    readonly property bool isToday: chosenDay === ""
    readonly property string day: chosenDay || today
    // The selected day across all applications. While another day is on its way
    // the previous numbers stay, so the charts glide instead of blinking.
    readonly property var overall: isToday ? todayStats : (dayStats ?? todayStats)
    // What the charts show: the application's own numbers while drilled in.
    readonly property var shown: app !== "" && appStats?.app === app ? appStats : overall

    readonly property Want topic: Want {
        topic: "focus"
    }

    readonly property Connections live: Connections {
        target: Daemon

        function onFocusChanged() {
            if (!Daemon.focus)
                return;
            root.todayStats = Daemon.focus;
            if (root.isToday && root.app !== "")
                root.fetch(true);
        }
    }

    function isoDate(date) {
        const two = n => (n < 10 ? "0" : "") + n;
        return date.getFullYear() + "-" + two(date.getMonth() + 1) + "-" + two(date.getDate());
    }

    function parseDate(iso) {
        const [year, month, day] = iso.split("-").map(Number);
        return new Date(year, month - 1, day);
    }

    // The day `days` after `iso`.
    function dayAfter(iso, days) {
        const date = parseDate(iso);
        date.setDate(date.getDate() + days);
        return isoDate(date);
    }

    // The future has no statistics: anything from today on selects today.
    function select(iso) {
        chosenDay = iso >= today ? "" : iso;
    }

    function shiftDays(days) {
        if (today !== "")
            select(dayAfter(day, days));
    }

    // The same day of the month `months` away, or that month's last day.
    function shiftMonths(months) {
        if (today === "")
            return;
        const from = parseDate(day);
        const target = new Date(from.getFullYear(), from.getMonth() + months, 1);
        const lastDay = new Date(target.getFullYear(), target.getMonth() + 1, 0).getDate();
        target.setDate(Math.min(from.getDate(), lastDay));
        select(isoDate(target));
    }

    // Drill into one application (an entry of `apps`), or switch to another.
    function drill(entry) {
        appName = entry.name;
        appIcon = entry.icon ?? "";
        app = entry.class;
    }

    function leaveApp() {
        app = "";
    }

    function fetch(forApp) {
        const params = {};
        if (chosenDay !== "")
            params.date = chosenDay;
        if (forApp)
            params.app = app;
        Daemon.call("focus.stats", params, (stats, failure) => {
            root.error = failure ?? "";
            if (stats)
                root.adopt(stats);
        });
    }

    // A reply can arrive after the selection has moved on: keep only what still fits.
    function adopt(stats) {
        if (stats.app) {
            if (stats.app === app && stats.date === day)
                appStats = stats;
        } else if (stats.date === stats.today) {
            todayStats = stats;
        } else if (stats.date === chosenDay) {
            dayStats = stats;
        }
    }

    // These handlers read only what the user chose: derived properties may
    // not have caught up yet while a change is being announced.
    onChosenDayChanged: {
        if (chosenDay !== "")
            fetch(false);
        if (app !== "")
            fetch(true);
    }
    onAppChanged: {
        if (app !== "")
            fetch(true);
    }
    // The topic first arrives a few seconds after it is wanted; do not wait for it.
    Component.onCompleted: fetch(false)
}
