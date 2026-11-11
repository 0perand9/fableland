import QtQuick
import qs.core
import qs.widgets
import qs.popups.focus

// Screen time: how long the selected day was, against the day before and the
// week's average, where in the week, the month and the day it went, and into
// which applications. Clicking an application shows all of it for that
// application alone. ←/→ move a day, Home/End (or Page Up/Down) a week;
// Escape or Backspace leaves an application.
PopupPage {
    id: page

    readonly property real margin: Theme.px(24)
    readonly property real gap: Theme.px(16)
    readonly property real topRowHeight: Theme.px(190)

    readonly property string dayTitle: {
        if (screenTime.day === "")
            return "";
        const date = screenTime.parseDate(screenTime.day);
        if (screenTime.isToday)
            return "Today · " + Qt.formatDate(date, "ddd, d MMM");
        if (screenTime.day === screenTime.dayAfter(screenTime.today, -1))
            return "Yesterday · " + Qt.formatDate(date, "ddd, d MMM");
        const sameYear = screenTime.day.slice(0, 4) === screenTime.today.slice(0, 4);
        return Qt.formatDate(date, sameYear ? "ddd, d MMMM" : "ddd, d MMM yyyy");
    }
    // The application's part of the day's total, while drilled in.
    readonly property string appShare: {
        const whole = screenTime.overall?.total ?? 0;
        if (screenTime.app === "" || screenTime.shown === screenTime.overall || whole <= 0)
            return "";
        return Math.round(100 * screenTime.shown.total / whole) + "% of the day";
    }

    implicitWidth: Theme.px(900)
    implicitHeight: Theme.px(700)
    closeOnEscape: screenTime.app === ""

    Keys.onPressed: event => {
        switch (event.key) {
        case Qt.Key_Left: screenTime.shiftDays(-1); break;
        case Qt.Key_Right: screenTime.shiftDays(1); break;
        case Qt.Key_Home: case Qt.Key_PageUp: screenTime.shiftDays(-7); break;
        case Qt.Key_End: case Qt.Key_PageDown: screenTime.shiftDays(7); break;
        case Qt.Key_Escape: case Qt.Key_Backspace:
            // Not in an application: Escape is the host's, to close the popup.
            if (screenTime.app === "")
                return;
            screenTime.leaveApp();
            break;
        default: return;
        }
        event.accepted = true;
    }

    FocusData {
        id: screenTime
    }

    Backdrop {
        anchors.fill: parent
        colors: [Theme.accent, Theme.blue, Theme.mauve]
        strength: 0.1
    }

    // ── what is shown: everything, or one application ──
    Row {
        id: heading

        x: page.margin
        y: Theme.px(18)
        height: Theme.px(40)
        spacing: Theme.px(12)

        IconBtn {
            anchors.verticalCenter: parent.verticalCenter
            visible: screenTime.app !== ""
            icon: Icons.arrowLeft
            size: 36
            onClicked: screenTime.leaveApp()
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.px(40)
            height: width
            radius: Theme.radiusSmall
            color: Theme.alpha(Theme.accent, 0.14)

            Icon {
                anchors.centerIn: parent
                visible: screenTime.app === ""
                text: Icons.chart
                size: 22
                color: Theme.accent
            }

            AppIcon {
                anchors.centerIn: parent
                visible: screenTime.app !== ""
                icon: screenTime.appIcon
                fallback: screenTime.app
                glyph: Icons.window
                size: 28
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.px(380)

            Txt {
                width: parent.width
                text: screenTime.app !== "" ? screenTime.appName : "Screen time"
                size: 16
                bold: true
            }

            Txt {
                width: parent.width
                text: screenTime.error !== "" ? "Could not load the statistics: " + screenTime.error : screenTime.app !== "" ? "This application only · Esc returns to all" : screenTime.todayStats?.current ? "Now in " + screenTime.todayStats.current : ""
                size: 11
                color: screenTime.error !== "" ? Theme.error : Theme.subtext
            }
        }
    }

    // ── the day ──
    Row {
        anchors.right: parent.right
        anchors.rightMargin: page.margin - Theme.px(6)
        anchors.verticalCenter: heading.verticalCenter
        spacing: Theme.px(4)

        Btn {
            anchors.verticalCenter: parent.verticalCenter
            visible: !screenTime.isToday
            height: Theme.px(32)
            text: "Today"
            icon: Icons.calendarToday
            kind: "flat"
            size: 12
            onClicked: screenTime.select(screenTime.today)
        }

        IconBtn {
            anchors.verticalCenter: parent.verticalCenter
            icon: Icons.chevronLeft
            onClicked: screenTime.shiftDays(-1)
        }

        Txt {
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.px(224)
            horizontalAlignment: Text.AlignHCenter
            text: page.dayTitle
            size: 14
            bold: true
        }

        IconBtn {
            anchors.verticalCenter: parent.verticalCenter
            icon: Icons.chevronRight
            interactive: !screenTime.isToday
            onClicked: screenTime.shiftDays(1)
        }
    }

    // ── left: the total and the applications ──
    Summary {
        id: summary

        x: page.margin
        anchors.top: heading.bottom
        anchors.topMargin: page.gap
        width: Theme.px(300)
        height: page.topRowHeight
        stats: screenTime.shown
        caption: screenTime.app !== "" ? "In this application" : "Screen time"
        remark: page.appShare
        previousLabel: screenTime.isToday ? "Yesterday" : "Day before"
    }

    AppList {
        anchors.left: summary.left
        anchors.right: summary.right
        anchors.top: summary.bottom
        anchors.bottom: parent.bottom
        anchors.topMargin: page.gap
        anchors.bottomMargin: page.margin
        stats: screenTime.overall
        selected: screenTime.app
        onAppSelected: app => {
            if (app.class === screenTime.app)
                screenTime.leaveApp();
            else
                screenTime.drill(app);
        }
    }

    // ── right: the week, the month, the day, the week by hour ──
    WeekBars {
        id: week

        anchors.left: summary.right
        anchors.right: month.left
        anchors.top: summary.top
        anchors.leftMargin: page.gap
        anchors.rightMargin: page.gap
        height: page.topRowHeight
        stats: screenTime.shown
        onDaySelected: date => screenTime.select(date)
    }

    MonthGrid {
        id: month

        anchors.right: parent.right
        anchors.rightMargin: page.margin
        anchors.top: summary.top
        width: Theme.px(232)
        height: page.topRowHeight
        stats: screenTime.shown
        onDaySelected: date => screenTime.select(date)
        onMonthShifted: months => screenTime.shiftMonths(months)
    }

    Timeline {
        id: timeline

        anchors.left: week.left
        anchors.right: month.right
        anchors.top: week.bottom
        anchors.topMargin: page.gap
        height: Theme.px(150)
        stats: screenTime.shown
    }

    Heatmap {
        anchors.left: week.left
        anchors.right: month.right
        anchors.top: timeline.bottom
        anchors.bottom: parent.bottom
        anchors.topMargin: page.gap
        anchors.bottomMargin: page.margin
        stats: screenTime.shown
        onDaySelected: date => screenTime.select(date)
    }
}
