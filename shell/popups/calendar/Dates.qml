pragma Singleton
import QtQuick
import Quickshell

// Calendar arithmetic for the calendar popup. Days travel as "yyyy-MM-dd" keys
// (the daemon's format, which also sorts correctly as text) and months as one
// number, year × 12 + month, so that stepping through either is plain arithmetic.
Singleton {
    function key(date) {
        const two = n => (n < 10 ? "0" : "") + n;
        return date.getFullYear() + "-" + two(date.getMonth() + 1) + "-" + two(date.getDate());
    }

    function date(dayKey) {
        const parts = dayKey.split("-");
        return new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]));
    }

    // "Tue 10 Nov"
    function label(dayKey) {
        return Qt.formatDateTime(date(dayKey), "ddd d MMM");
    }

    function addDays(dayKey, days) {
        const d = date(dayKey);
        d.setDate(d.getDate() + days);
        return key(d);
    }

    // The same day of another month, or that month's last day when it is shorter.
    function addMonths(dayKey, months) {
        const from = date(dayKey);
        const to = new Date(from.getFullYear(), from.getMonth() + months, 1);
        const lastDay = new Date(to.getFullYear(), to.getMonth() + 1, 0).getDate();
        to.setDate(Math.min(from.getDate(), lastDay));
        return key(to);
    }

    function monthOf(dayKey) {
        const parts = dayKey.split("-");
        return Number(parts[0]) * 12 + Number(parts[1]) - 1;
    }

    function monthStart(month) {
        return new Date(Math.floor(month / 12), month % 12, 1);
    }

    // "yyyy-MM", the way `misc.diaryDays` takes a month.
    function monthKey(month) {
        return key(monthStart(month)).slice(0, 7);
    }
}
