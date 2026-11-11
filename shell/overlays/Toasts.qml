import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core
import qs.widgets

// Notification pop-ups in the top right corner. The daemon is the notification
// server and keeps the history; this only shows what just arrived ("notif.new")
// and short messages from the daemon itself ("toast").
PanelWindow {
    id: win

    readonly property int limit: 5
    // key → notification; the model only holds the order.
    property var items: ({})
    property int lastToast: 0

    function add(key, item) {
        const fresh = !(key in items);
        items[key] = item;
        itemsChanged();
        if (!fresh)
            return;
        order.insert(0, { key: key, leaving: false });
        if (order.count > limit)
            drop(order.get(order.count - 1).key);
    }

    // Animate a toast out; it removes itself when done.
    function dismiss(key) {
        for (let i = 0; i < order.count; i++)
            if (order.get(i).key === key)
                order.setProperty(i, "leaving", true);
    }

    function drop(key) {
        for (let i = 0; i < order.count; i++)
            if (order.get(i).key === key)
                order.remove(i);
        delete items[key];
    }

    screen: Ui.focusedScreen
    visible: order.count > 0 && !Ui.locked
    anchors {
        top: true
        right: true
    }
    margins.top: Theme.px(4)
    margins.right: Theme.px(8)
    implicitWidth: Theme.px(400)
    implicitHeight: Math.max(1, column.implicitHeight)
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "fableland-toasts"
    mask: Region {
        item: column
    }

    ListModel {
        id: order
    }

    Connections {
        target: Daemon

        function onEvent(name, data) {
            if (name === "notif.new")
                win.add("n" + data.id, data);
            else if (name === "notif.closed")
                win.dismiss("n" + data.id);
            else if (name === "toast")
                win.add("t" + (++win.lastToast), { toast: true, kind: data.kind, app: "Fableland", summary: data.title, body: data.body ?? "", timeout: 4500, actions: [] });
        }
    }

    Column {
        id: column

        width: parent.width
        spacing: Theme.px(8)

        move: Transition {
            NumberAnimation { properties: "y"; duration: Theme.normal; easing.type: Easing.OutCubic }
        }

        Repeater {
            model: order

            Rectangle {
                id: toast

                required property string key
                required property bool leaving
                readonly property var item: win.items[key] ?? ({})
                readonly property bool isToast: !!item.toast
                readonly property bool critical: item.urgency === 2 || item.kind === "error"
                readonly property color hue: critical ? Theme.red : item.kind === "success" ? Theme.green : Theme.accent
                readonly property bool hasDefault: (item.actions ?? []).some(a => a.id === "default")
                readonly property var buttons: (item.actions ?? []).filter(a => a.id !== "default")
                property bool entered: false

                function invoke(action) {
                    Daemon.send("notif.invoke", { id: item.id, action: action });
                    win.dismiss(key);
                }

                width: column.width
                implicitHeight: body.implicitHeight + Theme.px(24)
                radius: Theme.radius
                color: Theme.alpha(Theme.base, 0.94)
                border.width: 1
                border.color: critical ? Theme.alpha(Theme.red, 0.5) : Theme.border
                clip: true
                opacity: entered && !leaving ? 1 : 0
                transform: Translate {
                    x: toast.entered && !toast.leaving ? 0 : Theme.px(40)

                    Behavior on x {
                        NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic }
                    }
                }
                Component.onCompleted: entered = true
                onLeavingChanged: if (leaving) remove.start()

                Behavior on opacity {
                    NumberAnimation { duration: Theme.normal }
                }

                Timer {
                    id: remove

                    interval: Theme.normal
                    onTriggered: win.drop(toast.key)
                }

                // Counts down while the pointer is elsewhere; 0 means "stay until dismissed".
                NumberAnimation {
                    id: countdown

                    target: timeBar
                    property: "remaining"
                    from: 1
                    to: 0
                    duration: Math.max(1, toast.item.timeout ?? 0)
                    running: (toast.item.timeout ?? 0) > 0 && !toast.leaving
                    paused: running && hover.hovered
                    onFinished: win.dismiss(toast.key)
                }

                HoverHandler {
                    id: hover
                }

                TapHandler {
                    onTapped: toast.hasDefault ? toast.invoke("default") : win.dismiss(toast.key)
                }

                Row {
                    id: body

                    x: Theme.px(14)
                    y: Theme.px(12)
                    width: parent.width - Theme.px(28)
                    spacing: Theme.px(12)

                    Item {
                        id: picture

                        width: Theme.px(40)
                        height: Theme.px(40)

                        RoundImage {
                            anchors.fill: parent
                            visible: !!toast.item.image
                            radius: Theme.px(10)
                            source: Fmt.file(toast.item.image ?? "")
                        }

                        AppIcon {
                            anchors.centerIn: parent
                            visible: !toast.item.image && !toast.isToast
                            icon: toast.item.icon || toast.item.desktopEntry || ""
                            fallback: "dialog-information"
                            glyph: Icons.bell
                            size: 34
                        }

                        Icon {
                            anchors.centerIn: parent
                            visible: toast.isToast
                            text: toast.critical ? Icons.error : toast.item.kind === "success" ? Icons.checkCircle : Icons.info
                            size: 28
                            color: toast.hue
                        }
                    }

                    Column {
                        width: parent.width - picture.width - parent.spacing
                        spacing: Theme.px(2)

                        Item {
                            width: parent.width
                            height: Theme.px(18)

                            Txt {
                                anchors.left: parent.left
                                anchors.right: closeButton.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: toast.item.app ?? ""
                                size: 11
                                bold: true
                                color: toast.hue
                            }

                            IconBtn {
                                id: closeButton

                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                icon: Icons.close
                                size: 22
                                iconColor: Theme.subtext
                                opacity: hover.hovered ? 1 : 0
                                // Closing by hand also removes it from the history.
                                onClicked: {
                                    if (!toast.isToast)
                                        Daemon.send("notif.dismiss", { id: toast.item.id });
                                    win.dismiss(toast.key);
                                }
                            }
                        }

                        Txt {
                            width: parent.width
                            visible: text !== ""
                            text: toast.item.summary ?? ""
                            size: 13
                            bold: true
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                        }

                        Txt {
                            width: parent.width
                            visible: text !== ""
                            text: toast.item.body ?? ""
                            size: 12
                            color: Theme.subtext
                            textFormat: Text.StyledText
                            wrapMode: Text.Wrap
                            maximumLineCount: 4
                            linkColor: Theme.accent
                        }

                        Row {
                            visible: toast.buttons.length > 0
                            topPadding: Theme.px(8)
                            spacing: Theme.px(6)

                            Repeater {
                                model: toast.buttons

                                Btn {
                                    required property var modelData

                                    implicitHeight: Theme.px(28)
                                    text: modelData.label
                                    size: 11
                                    onClicked: toast.invoke(modelData.id)
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    id: timeBar

                    property real remaining: 0

                    // Kept clear of the rounded corners.
                    x: toast.radius
                    anchors.bottom: parent.bottom
                    width: (parent.width - 2 * x) * remaining
                    height: Theme.px(2)
                    radius: height / 2
                    color: Theme.alpha(toast.hue, 0.7)
                    visible: countdown.running
                }
            }
        }
    }
}
