import QtQuick
import Quickshell
import qs.core
import qs.widgets
import qs.popups.calendar

// The calendar: the month and the diary on the left, the clock inside an orbit
// of hourly weather in the middle, the forecast on the right and — for users
// with a schedule feed — the day's timeline underneath.
//
// One day is selected at a time (arrow keys, or a click on a forecast day).
// The weather shows its forecast while there is one, the schedule its events,
// and Enter opens its diary note. Without the weather feature the forecast
// wing is left out and the clock stands alone.
PopupPage {
    id: page

    readonly property var weather: Daemon.weather
    readonly property bool hasWeather: Daemon.has("weather")
    readonly property var schedule: Daemon.schedule
    readonly property bool hasSchedule: schedule.available === true
    readonly property var days: weather.days ?? []

    // Today as a day key. Being text, it changes — and wakes what depends on it — at midnight only.
    readonly property string todayKey: Dates.key(clock.date)
    // The selected day: today, until another one is chosen.
    property string selectedKey: todayKey
    // The month the grid shows, as year × 12 + month.
    property int month: Dates.monthOf(todayKey)
    // The forecast day on show: the selected day while the forecast reaches it, otherwise the last one that was.
    property int dayIndex: 0
    readonly property var day: days[Math.min(dayIndex, days.length - 1)] ?? null

    // The mood of the hour: warm mornings, clear afternoons, mauve evenings, blue nights.
    readonly property color timeHue: {
        const hour = clock.hours;
        return hour < 5 || hour >= 21 ? Theme.blue : hour < 12 ? Theme.peach : hour < 17 ? Theme.sapphire : Theme.mauve;
    }

    // 0 → 1 as the popup arrives: the wings slide in from their sides, the clock grows from the middle.
    property real arrival: 0

    function select(dayKey) {
        selectedKey = dayKey;
        month = Dates.monthOf(dayKey);
        showForecastOf(dayKey);
    }

    function showForecastOf(dayKey) {
        const index = days.findIndex(day => day.date === dayKey);
        if (index >= 0)
            dayIndex = index;
    }

    // The note opens in another program, so the popup gets out of its way.
    function openNote(dayKey) {
        Daemon.send("misc.diaryOpen", { date: dayKey });
        close();
    }

    implicitWidth: Theme.px(hasWeather ? 1450 : 1120)
    implicitHeight: Theme.px(hasSchedule ? 750 : 510)
    placement: "top"

    // A weather update can move the days along (after midnight the first one is gone).
    onDaysChanged: showForecastOf(selectedKey)

    Keys.onPressed: event => {
        switch (event.key) {
        case Qt.Key_Left: select(Dates.addDays(selectedKey, -1)); break;
        case Qt.Key_Right: select(Dates.addDays(selectedKey, 1)); break;
        case Qt.Key_Up: select(Dates.addDays(selectedKey, -7)); break;
        case Qt.Key_Down: select(Dates.addDays(selectedKey, 7)); break;
        case Qt.Key_PageUp: select(Dates.addMonths(selectedKey, -1)); break;
        case Qt.Key_PageDown: select(Dates.addMonths(selectedKey, 1)); break;
        case Qt.Key_Home: select(todayKey); break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_Space: openNote(selectedKey); break;
        default: return;
        }
        event.accepted = true;
    }

    SystemClock {
        id: clock

        precision: SystemClock.Seconds
    }

    NumberAnimation on arrival {
        from: 0
        to: 1
        duration: Theme.slow
        easing.type: Easing.OutCubic
    }

    Backdrop {
        anchors.fill: parent
        // The weather's colour changes with the orbit, while that is spun away.
        colors: [Theme.weatherColor(hub.shown?.condition ?? ""), page.timeHue, Theme.accent]
    }

    Item {
        id: upper

        width: parent.width
        height: Theme.px(510)

        Hub {
            id: hub

            anchors.left: monthCard.right
            anchors.right: forecast.left
            height: parent.height
            scale: 0.9 + 0.1 * page.arrival
            now: clock.date
            todayKey: page.todayKey
            day: page.day
        }

        MonthCard {
            id: monthCard

            x: Theme.px(24)
            y: Theme.px(24)
            width: Theme.px(330)
            height: parent.height - 2 * y
            opacity: page.arrival
            transform: Translate {
                x: -Theme.px(30) * (1 - page.arrival)
            }
            todayKey: page.todayKey
            selectedKey: page.selectedKey
            month: page.month
            onMonthShifted: by => page.month += by
            onTodayRequested: page.select(page.todayKey)
            onNoteRequested: dayKey => page.openNote(dayKey)
        }

        WeatherPanel {
            id: forecast

            visible: page.hasWeather
            anchors.right: parent.right
            anchors.rightMargin: Theme.px(24)
            y: Theme.px(24)
            width: visible ? Theme.px(330) : 0
            height: parent.height - 2 * y
            opacity: page.arrival
            transform: Translate {
                x: Theme.px(30) * (1 - page.arrival)
            }
            weather: page.weather
            todayKey: page.todayKey
            day: page.day
            dayIndex: page.dayIndex
            onDaySelected: index => page.select(page.days[index].date)
        }
    }

    Loader {
        anchors.top: upper.bottom
        anchors.bottom: parent.bottom
        width: parent.width
        active: page.hasSchedule
        sourceComponent: ScheduleStrip {
            schedule: page.schedule
            todayKey: page.todayKey
            dayKey: page.selectedKey
            now: clock.date
        }
    }
}
