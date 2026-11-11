import QtQuick
import qs.core
import qs.widgets

// The notification history, grouped by application with the newest on top,
// and the do-not-disturb switch.
Item {
    id: root

    readonly property var notif: Daemon.notif
    readonly property int count: notif.items.length
    // Applications whose group is folded away: app → true.
    property var folded: ({})
    // Advanced every half minute so that the ages ("5m") stay current.
    property real now: Date.now()

    // Group headers and their notifications in display order:
    //   [{ id: "app:Discord", app, count, icon, folded }, { id: 12, … }, { id: 9, … }, …]
    // The history is newest first, so groups come out ordered by their latest
    // notification, each holding its own newest first.
    readonly property var entries: {
        const groups = new Map();
        for (const item of notif.items) {
            if (!groups.has(item.app))
                groups.set(item.app, []);
            groups.get(item.app).push(item);
        }
        const flat = [];
        for (const [app, items] of groups) {
            const hidden = !!folded[app];
            flat.push({ id: "app:" + app, app: app, count: items.length, icon: items[0].desktopEntry || items[0].icon, folded: hidden });
            if (!hidden)
                flat.push(...items);
        }
        return flat;
    }

    function toggleFold(app) {
        const next = Object.assign({}, folded);
        if (next[app])
            delete next[app];
        else
            next[app] = true;
        folded = next;
    }

    // For the keyboard: scroll the history by a number of pixels.
    function scrollBy(distance) {
        const end = Math.max(list.originY, list.originY + list.contentHeight - list.height);
        list.contentY = Math.max(list.originY, Math.min(end, list.contentY + distance));
    }

    Timer {
        interval: 30000
        repeat: true
        running: root.visible
        onTriggered: root.now = Date.now()
    }

    KeyedModel {
        id: rows

        source: root.entries
    }

    // ── title ──
    Item {
        id: title

        width: parent.width
        height: Theme.px(32)

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.px(10)

            Txt {
                anchors.verticalCenter: parent.verticalCenter
                text: "Notifications"
                size: 17
                bold: true
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.count > 0
                width: Math.max(height, badge.implicitWidth + Theme.px(12))
                height: Theme.px(20)
                radius: height / 2
                color: Theme.alpha(Theme.yellow, 0.18)

                Txt {
                    id: badge

                    anchors.centerIn: parent
                    text: root.count
                    size: 11
                    bold: true
                    color: Theme.yellow
                }
            }
        }

        Btn {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: root.count > 0
            height: Theme.px(30)
            kind: "flat"
            accentColor: Theme.subtext
            text: "Clear all"
            size: 12
            onClicked: Daemon.send("notif.clear")
        }
    }

    // ── do not disturb ──
    Card {
        id: dnd

        anchors.top: title.bottom
        anchors.topMargin: Theme.px(12)
        width: parent.width
        height: Theme.px(52)
        color: root.notif.dnd ? Theme.alpha(Theme.yellow, 0.12) : Theme.alpha(Theme.surface0, 0.55)
        border.color: root.notif.dnd ? Theme.alpha(Theme.yellow, 0.45) : Theme.border

        Behavior on color {
            ColorAnimation { duration: Theme.normal }
        }

        Icon {
            id: dndIcon

            x: Theme.px(14)
            anchors.verticalCenter: parent.verticalCenter
            text: root.notif.dnd ? Icons.bellOff : Icons.bell
            size: 19
            color: root.notif.dnd ? Theme.yellow : Theme.subtext
        }

        Column {
            anchors.left: dndIcon.right
            anchors.leftMargin: Theme.px(12)
            anchors.right: dndSwitch.left
            anchors.rightMargin: Theme.px(12)
            anchors.verticalCenter: parent.verticalCenter

            Txt {
                width: parent.width
                text: "Do not disturb"
                size: 13
                bold: true
            }

            Txt {
                width: parent.width
                text: root.notif.dnd ? "Only urgent notifications pop up" : "Notifications pop up as they arrive"
                size: 10
                color: Theme.subtext
            }
        }

        Toggle {
            id: dndSwitch

            anchors.right: parent.right
            anchors.rightMargin: Theme.px(14)
            anchors.verticalCenter: parent.verticalCenter
            checked: root.notif.dnd
            accentColor: Theme.yellow
            onToggled: checked => Daemon.send("notif.setDnd", { on: checked })
        }
    }

    // ── nothing to show ──
    Column {
        anchors.centerIn: list
        opacity: root.count === 0 ? 1 : 0
        visible: opacity > 0
        spacing: Theme.px(6)

        Behavior on opacity {
            NumberAnimation { duration: Theme.slow }
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Theme.px(88)
            height: width
            radius: width / 2
            color: Theme.alpha(Theme.yellow, 0.1)
            border.width: 1
            border.color: Theme.alpha(Theme.yellow, 0.22)

            Icon {
                anchors.centerIn: parent
                text: root.notif.dnd ? Icons.bellOff : Icons.bellOutline
                size: 38
                color: Theme.yellow
            }
        }

        Item {
            width: 1
            height: Theme.px(8)
        }

        Txt {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "You're all caught up"
            size: 14
            bold: true
        }

        Txt {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.notif.dnd ? "New notifications will wait here quietly" : "New notifications will be kept here"
            size: 11
            color: Theme.dim
        }
    }

    // ── the history ──
    List {
        id: list

        anchors.top: dnd.bottom
        anchors.topMargin: Theme.px(6)
        anchors.bottom: parent.bottom
        width: parent.width
        spacing: Theme.px(8)
        model: rows.rows

        add: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.normal }
        }
        remove: Transition {
            NumberAnimation { property: "opacity"; to: 0; duration: Theme.normal }
            NumberAnimation { property: "x"; to: Theme.px(48); duration: Theme.normal; easing.type: Easing.OutCubic }
        }
        // Rows moved while still fading in must end up fully shown.
        displaced: Transition {
            NumberAnimation { property: "y"; duration: Theme.normal; easing.type: Easing.OutCubic }
            NumberAnimation { property: "opacity"; to: 1; duration: Theme.normal }
        }

        delegate: Loader {
            id: slot

            required property string key
            // A removed row keeps what it last showed while it animates out.
            property var entry: ({})
            readonly property bool isGroup: key.startsWith("app:")

            width: list.width
            sourceComponent: isGroup ? group : card

            Binding on entry {
                when: slot.key in rows.byKey
                value: rows.byKey[slot.key]
                restoreMode: Binding.RestoreNone
            }

            Component {
                id: group

                NotificationGroup {
                    entry: slot.entry
                    onFoldToggled: root.toggleFold(slot.entry.app)
                }
            }

            Component {
                id: card

                NotificationCard {
                    entry: slot.entry
                    // Reading `root.now` makes the age follow the clock.
                    age: root.now && slot.entry.time ? Fmt.ago(slot.entry.time) : ""
                }
            }
        }
    }
}
