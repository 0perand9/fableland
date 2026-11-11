import QtQuick
import qs.core
import qs.widgets

// One notification in the history. Clicking it does what clicking its pop-up
// would have done — the default action — and its other actions are buttons.
Card {
    id: root

    // As in `notif.items`.
    property var entry: ({})
    // How long ago it arrived ("5m").
    property string age: ""
    // Long texts are cut to a few lines until asked for.
    property bool expanded: false

    readonly property bool critical: entry.urgency === 2
    readonly property var actions: (entry.actions ?? []).filter(action => action.label !== "")
    readonly property bool hasDefault: (entry.actions ?? []).some(action => action.id === "default")
    // Notification bodies are HTML-like: line breaks must be tags, and pictures
    // (which could be remote) are not wanted.
    readonly property string body: (entry.body ?? "").replace(/<img[^>]*>/gi, "").trim().replace(/\n/g, "<br>")

    function invoke(action) {
        Daemon.send("notif.invoke", { id: entry.id, action: action });
    }

    implicitHeight: content.implicitHeight + Theme.px(24)
    color: Theme.alpha(Theme.surface0, hover.hovered ? 0.85 : 0.55)
    border.color: critical ? Theme.alpha(Theme.red, 0.55) : hover.hovered ? Theme.alpha(Theme.text, 0.16) : Theme.border

    Behavior on color {
        ColorAnimation { duration: Theme.fast }
    }

    HoverHandler {
        id: hover

        cursorShape: root.hasDefault ? Qt.PointingHandCursor : Qt.ArrowCursor
    }

    TapHandler {
        enabled: root.hasDefault
        onTapped: root.invoke("default")
    }

    Row {
        id: content

        x: Theme.px(12)
        y: Theme.px(12)
        width: parent.width - 2 * x
        spacing: Theme.px(10)

        // The picture it came with; its icon if there is none (or it is gone).
        Item {
            id: thumb

            width: Theme.px(36)
            height: width

            RoundImage {
                id: picture

                anchors.fill: parent
                visible: loaded
                radius: Theme.px(8)
                source: Fmt.file(root.entry.image ?? "")
            }

            AppIcon {
                anchors.centerIn: parent
                visible: !picture.loaded
                icon: root.entry.icon ?? ""
                fallback: root.entry.desktopEntry ?? ""
                glyph: Icons.bell
                size: 30
            }
        }

        Column {
            width: parent.width - thumb.width - parent.spacing
            spacing: Theme.px(4)

            Item {
                width: parent.width
                height: Math.max(summary.implicitHeight, corner.height)

                Txt {
                    id: summary

                    anchors.left: parent.left
                    anchors.right: corner.left
                    anchors.rightMargin: Theme.px(6)
                    text: root.entry.summary || root.entry.app || "Notification"
                    size: 13
                    bold: true
                    color: root.critical ? Theme.red : Theme.text
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                }

                // The age makes way for the dismiss button while hovered.
                Item {
                    id: corner

                    anchors.right: parent.right
                    width: Theme.px(26)
                    height: Theme.px(22)

                    Txt {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !hover.hovered
                        text: root.age
                        size: 10
                        color: Theme.dim
                    }

                    IconBtn {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        visible: hover.hovered
                        icon: Icons.close
                        size: 22
                        iconColor: Theme.subtext
                        onClicked: Daemon.send("notif.dismiss", { id: root.entry.id })
                    }
                }
            }

            Txt {
                id: text

                width: parent.width
                visible: root.body !== ""
                text: root.body
                textFormat: Text.StyledText
                size: 12
                color: Theme.subtext
                linkColor: Theme.accent
                wrapMode: Text.Wrap
                maximumLineCount: root.expanded ? 40 : 3
                onLinkActivated: link => Daemon.send("misc.open", { target: link })
            }

            Flow {
                width: parent.width
                visible: root.actions.length > 0 || more.visible
                topPadding: Theme.px(4)
                spacing: Theme.px(6)

                Repeater {
                    model: root.actions

                    Btn {
                        required property var modelData

                        height: Theme.px(28)
                        text: modelData.label
                        size: 11
                        onClicked: root.invoke(modelData.id)
                    }
                }

                Btn {
                    id: more

                    visible: root.expanded || text.truncated
                    height: Theme.px(28)
                    kind: "flat"
                    accentColor: Theme.subtext
                    icon: root.expanded ? Icons.chevronUp : Icons.chevronDown
                    text: root.expanded ? "Less" : "More"
                    size: 11
                    onClicked: root.expanded = !root.expanded
                }
            }
        }
    }
}
