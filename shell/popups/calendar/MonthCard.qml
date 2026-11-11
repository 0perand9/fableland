import QtQuick
import qs.core
import qs.widgets

// A month of days. Days that have a diary entry carry a dot; clicking a day
// asks for its note. The card only reports what the user wants (another month,
// today, a note) — the popup owns the month and the selection.
Card {
    id: card

    required property string todayKey
    required property string selectedKey
    // The month on show, as year × 12 + month.
    required property int month

    signal monthShifted(int by)
    signal todayRequested
    signal noteRequested(string dayKey)

    readonly property date firstDay: Dates.monthStart(month)
    // Six weeks, Monday first: the month and the days around it.
    readonly property var cells: {
        const year = firstDay.getFullYear(), index = firstDay.getMonth();
        const leading = (firstDay.getDay() + 6) % 7;
        const days = [];
        for (let i = 0; i < 42; i++) {
            const date = new Date(year, index, 1 - leading + i);
            days.push({ key: Dates.key(date), day: date.getDate(), inMonth: date.getMonth() === index });
        }
        return days;
    }
    // "yyyy-MM" → the days of that month with a diary entry, filled in as the daemon answers.
    property var noteDays: ({})
    // The month shown before this one, to know which way the page turns.
    property int previousMonth: -1
    // The cell under the pointer, -1 if none. (A cell, not a day: the month can change under a resting pointer.)
    property int hoveredCell: -1
    // The day the footer talks about: the one a click would open, else the one Enter would.
    readonly property string hintKey: hoveredCell >= 0 ? cells[hoveredCell].key : selectedKey
    readonly property bool hintHasNote: hasNote(hintKey)
    readonly property bool away: month !== Dates.monthOf(todayKey) || selectedKey !== todayKey

    function hasNote(dayKey) {
        const days = noteDays[dayKey.slice(0, 7)];
        return !!days && days.indexOf(Number(dayKey.slice(8))) >= 0;
    }

    // Asks for the diary days of the month on show and of its neighbours, whose
    // last and first days fill the grid. Each month is asked for once.
    function loadNoteDays() {
        for (let m = month - 1; m <= month + 1; m++) {
            const monthKey = Dates.monthKey(m);
            if (monthKey in noteDays)
                continue;
            // Marks the month as asked for. The answer replaces the mark; a failure removes it, to ask again later.
            noteDays[monthKey] = [];
            Daemon.call("misc.diaryDays", { month: monthKey }, (days, error) => {
                const known = Object.assign({}, card.noteDays);
                if (error)
                    delete known[monthKey];
                else
                    known[monthKey] = days;
                card.noteDays = known;
            });
        }
    }

    onMonthChanged: {
        if (previousMonth >= 0 && previousMonth !== month) {
            slide.from = (month > previousMonth ? 1 : -1) * Theme.px(24);
            pageTurn.restart();
        }
        previousMonth = month;
        loadNoteDays();
    }
    Component.onCompleted: {
        previousMonth = month;
        loadNoteDays();
    }

    // One wheel notch per month; touchpads send many small steps.
    WheelHandler {
        property real travelled: 0

        // A wheel may arrive as a touchpad's, depending on the compositor; by default only a mouse's is heard.
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

        onWheel: event => {
            travelled += event.angleDelta.y;
            const notches = Math.trunc(travelled / 120);
            if (notches !== 0) {
                travelled -= notches * 120;
                card.monthShifted(-notches);
            }
        }
    }

    Item {
        id: header

        x: Theme.px(20)
        y: Theme.px(18)
        width: parent.width - 2 * x
        height: Theme.px(34)

        IconBtn {
            anchors.verticalCenter: parent.verticalCenter
            icon: Icons.chevronLeft
            size: 32
            onClicked: card.monthShifted(-1)
        }

        Txt {
            anchors.centerIn: parent
            text: Qt.formatDateTime(card.firstDay, "MMMM yyyy")
            size: 16
            bold: true
        }

        IconBtn {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            icon: Icons.chevronRight
            size: 32
            onClicked: card.monthShifted(1)
        }
    }

    Row {
        id: weekdays

        anchors.top: header.bottom
        anchors.topMargin: Theme.px(14)
        x: header.x
        spacing: grid.spacing

        Repeater {
            model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

            Txt {
                required property string modelData
                required property int index

                width: grid.cellWidth
                horizontalAlignment: Text.AlignHCenter
                text: modelData
                size: 11
                bold: true
                color: index >= 5 ? Theme.alpha(Theme.dim, 0.7) : Theme.dim
            }
        }
    }

    Grid {
        id: grid

        readonly property real cellWidth: (width - 6 * spacing) / 7
        readonly property real cellHeight: (height - 5 * spacing) / 6

        anchors.top: weekdays.bottom
        anchors.bottom: footer.top
        anchors.topMargin: Theme.px(8)
        anchors.bottomMargin: Theme.px(12)
        x: header.x
        width: header.width
        columns: 7
        spacing: Theme.px(4)
        transform: Translate {
            id: shift
        }

        Repeater {
            model: 42

            DayCell {
                required property int index
                readonly property var entry: card.cells[index]

                width: grid.cellWidth
                height: grid.cellHeight
                day: entry.day
                inMonth: entry.inMonth
                today: entry.key === card.todayKey
                selected: entry.key === card.selectedKey
                hasNote: card.hasNote(entry.key)
                onClicked: card.noteRequested(entry.key)
                onHoveredChanged: {
                    if (hovered)
                        card.hoveredCell = index;
                    else if (card.hoveredCell === index)
                        card.hoveredCell = -1;
                }
            }
        }
    }

    // A new month slides in from the side it lies on.
    ParallelAnimation {
        id: pageTurn

        NumberAnimation { id: slide; target: shift; property: "x"; to: 0; duration: Theme.normal; easing.type: Easing.OutCubic }
        NumberAnimation { target: grid; property: "opacity"; from: 0; to: 1; duration: Theme.normal; easing.type: Easing.OutCubic }
    }

    Item {
        id: footer

        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.px(14)
        x: header.x
        width: header.width
        height: Theme.px(32)

        // What a click (or Enter) on the day does.
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.px(8)

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                text: card.hintHasNote ? Icons.note : Icons.plus
                size: 16
                color: card.hintHasNote ? Theme.accent : Theme.dim
            }

            Txt {
                anchors.verticalCenter: parent.verticalCenter
                text: Dates.label(card.hintKey) + (card.hintHasNote ? " · open note" : " · new note")
                size: 12
                color: Theme.subtext
            }
        }

        Btn {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: Theme.px(30)
            visible: card.away
            kind: "flat"
            text: "Today"
            icon: Icons.calendarToday
            size: 12
            onClicked: card.todayRequested()
        }
    }
}
