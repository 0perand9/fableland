import QtQuick
import qs.core
import qs.widgets

// The schedule of one day as a timeline: events laid out by their times, the
// breaks between them and a marker for now. The feed is whatever the user's
// `schedule.command` prints, so nothing about it is taken for granted.
Item {
    id: strip

    // The `schedule` topic.
    required property var schedule
    required property string todayKey
    // The day whose events are shown.
    required property string dayKey
    required property date now

    readonly property bool today: dayKey === todayKey
    readonly property int nowMinute: now.getHours() * 60 + now.getMinutes()
    // The day's events in order, their times as minutes since midnight. Entries
    // without a start time are left out; one without a (later) end gets half an hour.
    readonly property var events: {
        const text = value => typeof value === "string" ? value : "";
        const found = [];
        for (const entry of Array.isArray(schedule.events) ? schedule.events : []) {
            const start = minuteOf(entry?.start), end = minuteOf(entry?.end);
            // An event without a date is today's.
            if (isNaN(start) || (entry.date ?? todayKey) !== dayKey)
                continue;
            found.push({
                id: start + " " + text(entry.title), title: text(entry.title), where: text(entry.where), note: text(entry.note),
                start: start, end: end > start ? end : start + 30
            });
        }
        return found.sort((a, b) => a.start - b.start);
    }
    // The free time between one event and the next.
    readonly property var breaks: {
        const gaps = [];
        for (let i = 1; i < events.length; i++)
            if (events[i].start > events[i - 1].end)
                gaps.push({ start: events[i - 1].end, end: events[i].start });
        return gaps;
    }
    // The timeline runs from the full hour before the first event to the full hour after the last,
    // widened evenly to at least six hours: a lone event should not span the whole strip.
    readonly property int firstHour: events.length > 0 ? Math.floor(events[0].start / 60) : 0
    readonly property int lastHour: Math.ceil(events.reduce((latest, e) => Math.max(latest, e.end), 0) / 60)
    readonly property int padding: Math.max(0, Math.ceil((6 - (lastHour - firstHour)) / 2))
    readonly property int startsAt: Math.max(0, firstHour - padding) * 60
    readonly property int endsAt: Math.min(24, lastHour + padding) * 60
    // The day fills the width, unless that would squeeze an hour too small to read — then it scrolls.
    readonly property real perMinute: Math.max(track.width / (endsAt - startsAt), Theme.px(150) / 60)
    property string hoveredId: ""
    readonly property var hoveredEvent: events.find(e => e.id === hoveredId) ?? null
    readonly property var currentEvent: today ? (events.find(e => e.start <= nowMinute && nowMinute < e.end) ?? null) : null
    // What is on, or what comes next.
    readonly property string summary: {
        if (events.length === 0)
            return "";
        if (!today)
            return events.length === 1 ? "1 event" : events.length + " events";
        if (currentEvent)
            return currentEvent.title + " · " + Fmt.duration((currentEvent.end - nowMinute) * 60) + " left";
        const next = events.find(e => e.start > nowMinute);
        return next ? next.title + " in " + Fmt.duration((next.start - nowMinute) * 60) : "Done for today";
    }

    // "09:30" → 570; NaN for anything that is not a time.
    function minuteOf(clock) {
        const match = /^(\d{1,2}):(\d{2})$/.exec(clock);
        return match ? Number(match[1]) * 60 + Number(match[2]) : NaN;
    }

    function clockOf(minute) {
        const two = n => (n < 10 ? "0" : "") + n;
        return two(Math.floor(minute / 60)) + ":" + two(minute % 60);
    }

    function span(entry) {
        return clockOf(entry.start) + " – " + clockOf(entry.end);
    }

    // Where a minute of the day lies on the timeline.
    function at(minute) {
        return (minute - startsAt) * perMinute;
    }

    function phaseOf(entry) {
        if (!today)
            return dayKey < todayKey ? "past" : "ahead";
        return entry.end <= nowMinute ? "past" : entry.start <= nowMinute ? "now" : "ahead";
    }

    function scrollTo(position) {
        track.contentX = Math.max(0, Math.min(track.contentWidth - track.width, position));
    }

    // Today opens with the present in view; other days from their start.
    function showNow() {
        scrollTo(today ? at(nowMinute) - track.width / 3 : 0);
    }

    // Later: once the timeline has taken the new day's shape.
    onDayKeyChanged: Qt.callLater(showNow)

    // The wheel moves along the timeline.
    WheelHandler {
        // A wheel may arrive as a touchpad's, depending on the compositor; by default only a mouse's is heard.
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => strip.scrollTo(track.contentX - event.angleDelta.y)
    }

    KeyedModel {
        id: entries

        source: strip.events
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: Theme.alpha(Theme.crust, 0) }
            GradientStop { position: 1; color: Theme.alpha(Theme.crust, 0.6) }
        }
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.border
    }

    Item {
        id: header

        x: Theme.px(24)
        y: Theme.px(16)
        width: parent.width - 2 * x
        height: Theme.px(36)

        Rectangle {
            id: badge

            width: height
            height: parent.height
            radius: height / 2
            color: Theme.alpha(Theme.surface1, 0.7)

            Icon {
                anchors.centerIn: parent
                text: Icons.calendar
                size: 18
                color: Theme.accent
            }
        }

        Column {
            id: heading

            anchors.left: badge.right
            anchors.leftMargin: Theme.px(12)
            anchors.verticalCenter: parent.verticalCenter

            Txt {
                text: strip.schedule.title ?? "Schedule"
                size: 15
                bold: true
            }

            Txt {
                text: strip.today ? "Today" : Dates.label(strip.dayKey)
                size: 11
                color: Theme.subtext
            }
        }

        // The event under the pointer in full (its block may be too narrow for that), otherwise the summary.
        Txt {
            anchors.left: heading.right
            anchors.right: link.visible ? link.left : parent.right
            anchors.leftMargin: Theme.px(24)
            anchors.rightMargin: link.visible ? Theme.px(16) : 0
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
            text: {
                const e = strip.hoveredEvent;
                return e ? [e.title, strip.span(e), e.where, e.note].filter(part => part !== "").join(" · ") : strip.summary;
            }
            size: 12
            color: strip.hoveredEvent ? Theme.text : Theme.subtext
        }

        // Feeds may name a page with the full schedule.
        Btn {
            id: link

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: typeof strip.schedule.link === "string" && strip.schedule.link !== ""
            text: "Open"
            icon: Icons.openExternal
            onClicked: {
                Daemon.send("misc.open", { target: strip.schedule.link });
                Ui.close();
            }
        }
    }

    Txt {
        anchors.centerIn: track
        visible: strip.events.length === 0
        text: "Nothing scheduled " + (strip.today ? "today" : "on " + Dates.label(strip.dayKey))
        color: Theme.dim
    }

    Flickable {
        id: track

        // The height of the events; the hours are written underneath.
        readonly property real rowHeight: height - Theme.px(22)

        anchors.fill: parent
        anchors.leftMargin: header.x
        anchors.rightMargin: header.x
        anchors.topMargin: header.y + header.height + Theme.px(14)
        anchors.bottomMargin: Theme.px(14)
        visible: strip.events.length > 0
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.HorizontalFlick
        contentWidth: strip.at(strip.endsAt)
        contentHeight: height
        onContentWidthChanged: Qt.callLater(strip.showNow)

        Repeater {
            model: (strip.endsAt - strip.startsAt) / 60

            Item {
                required property int index
                readonly property int minute: strip.startsAt + index * 60

                x: strip.at(minute)

                Rectangle {
                    y: track.rowHeight + Theme.px(4)
                    width: 1
                    height: Theme.px(6)
                    color: Theme.alpha(Theme.text, 0.25)
                }

                Txt {
                    x: Theme.px(6)
                    y: track.rowHeight + Theme.px(7)
                    text: strip.clockOf(parent.minute)
                    size: 10
                    color: Theme.dim
                }
            }
        }

        Repeater {
            model: strip.breaks

            Txt {
                required property var modelData

                x: strip.at(modelData.start)
                width: strip.at(modelData.end) - x
                height: track.rowHeight
                visible: width >= Theme.px(36)
                horizontalAlignment: Text.AlignHCenter
                text: Fmt.duration((modelData.end - modelData.start) * 60)
                size: 10
                color: Theme.dim
            }
        }

        // Now, in the clock's colour: a dot on the hours and, between events, a line.
        // (Inside an event the front of its liquid says the same.)
        Rectangle {
            visible: strip.today && strip.nowMinute >= strip.startsAt && strip.nowMinute <= strip.endsAt
            x: strip.at(strip.nowMinute) - width / 2
            y: track.rowHeight
            width: Theme.px(8)
            height: width
            radius: width / 2
            color: Theme.blue

            Rectangle {
                visible: !strip.currentEvent
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.top
                width: Theme.px(2)
                height: track.rowHeight
                radius: width / 2
                color: Theme.blue
            }
        }

        Repeater {
            model: entries.rows

            ScheduleEvent {
                required property string key
                readonly property var entry: entries.byKey[key] ?? ({ start: 0, end: 0 })

                x: strip.at(entry.start)
                // A hair of space keeps back-to-back events apart.
                width: Math.max(Theme.px(8), strip.at(entry.end) - x - Theme.px(4))
                height: track.rowHeight
                title: entry.title ?? ""
                time: strip.span(entry)
                where: entry.where ?? ""
                note: entry.note ?? ""
                phase: strip.phaseOf(entry)
                progress: (strip.nowMinute - entry.start) / Math.max(1, entry.end - entry.start)
                onHoveredChanged: {
                    if (hovered)
                        strip.hoveredId = key;
                    else if (strip.hoveredId === key)
                        strip.hoveredId = "";
                }
            }
        }
    }

    // How far along the timeline the view is, when the day is longer than the strip.
    Rectangle {
        visible: track.visible && track.visibleArea.widthRatio < 1
        x: track.x + track.visibleArea.xPosition * track.width
        y: parent.height - Theme.px(7)
        width: track.visibleArea.widthRatio * track.width
        height: Theme.px(3)
        radius: height / 2
        color: Theme.alpha(Theme.text, 0.25)
    }
}
