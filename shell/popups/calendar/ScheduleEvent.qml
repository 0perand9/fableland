import QtQuick
import Quickshell.Widgets
import qs.core
import qs.widgets

// One event on the schedule's timeline. The event that is on right now fills
// with liquid as it goes by; the ones that are over fade.
ClippingRectangle {
    id: event

    property string title: ""
    property string time: ""
    property string where: ""
    property string note: ""
    // "past", "now" or "ahead"
    property string phase: "ahead"
    // 0 … 1: how much of the event has gone by.
    property real progress: 0
    readonly property bool hovered: hover.hovered
    readonly property bool now: phase === "now"
    // Too narrow for more than the title.
    readonly property bool compact: width < Theme.px(96)

    radius: Theme.radiusSmall
    color: Theme.alpha(Theme.surface0, hovered ? 0.9 : 0.55)
    border.width: 1
    border.color: now ? Theme.alpha(Theme.accent, 0.5) : Theme.border
    opacity: phase === "past" && !hovered ? 0.5 : 1

    Behavior on color {
        ColorAnimation { duration: Theme.fast }
    }
    Behavior on opacity {
        NumberAnimation { duration: Theme.fast }
    }

    HoverHandler {
        id: hover
    }

    // Wave fills from its bottom; turned on its side it fills along the timeline, its surface marking now.
    Wave {
        anchors.centerIn: parent
        width: parent.height
        height: parent.width
        rotation: 90
        visible: event.now
        level: event.progress
        color: Theme.alpha(Theme.accent, 0.16)
    }

    Rectangle {
        width: Theme.px(event.now || event.hovered ? 4 : 2)
        height: parent.height
        color: event.now ? Theme.accent : event.hovered ? Theme.subtext : Theme.surface2

        Behavior on width {
            NumberAnimation { duration: Theme.normal; easing.type: Easing.OutBack }
        }
    }

    Column {
        x: Theme.px(event.compact ? 10 : 14)
        width: parent.width - x - Theme.px(8)
        anchors.verticalCenter: parent.verticalCenter
        // A sliver of an event says nothing itself; the strip's header does when it is pointed at.
        visible: event.width >= Theme.px(48)
        spacing: Theme.px(5)

        Txt {
            width: parent.width
            text: event.title
            size: 14
            bold: true
            color: event.now ? Theme.accent : Theme.text
        }

        Detail {
            icon: Icons.clock
            text: event.time
        }

        Detail {
            icon: Icons.place
            text: event.where
            tone: Theme.peach
        }

        Detail {
            icon: Icons.note
            text: event.note
        }
    }

    // A line of small print with its icon; absent when there is nothing to say or no room.
    component Detail: Row {
        id: detail

        property string icon: ""
        property string text: ""
        property color tone: Theme.dim

        width: parent.width
        visible: text !== "" && !event.compact
        spacing: Theme.px(6)

        Icon {
            id: glyph

            anchors.verticalCenter: parent.verticalCenter
            text: detail.icon
            size: 13
            color: detail.tone
        }

        Txt {
            anchors.verticalCenter: parent.verticalCenter
            width: detail.width - glyph.width - detail.spacing
            text: detail.text
            size: 11
            color: Theme.subtext
        }
    }
}
