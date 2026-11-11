import QtQuick
import Quickshell.Widgets
import qs.core
import qs.widgets

// A card riding the orbit around the hub: a network, a device, or a fact about
// the connection in use.
Item {
    id: root

    required property Orbit orbit
    // Where on the orbit: slot `slot` of `slots`, on riding ring `ring` (0 inner, 1 outer).
    property int slot: 0
    property int slots: 1
    property int ring: 0

    property string icon: ""
    property string title: ""
    // Shrink a long title to fit (for values such as addresses) rather than cutting it.
    property bool fitTitle: false
    property string note: ""
    // Replaces the note while hovered: what a click does.
    property string hint: ""
    property color hue: Theme.accent
    // "" · "known" (saved, paired) · "linked" (in use) · "busy" · "failed"
    property string tone: ""
    property bool interactive: true
    // The keyboard cursor is on this card.
    property bool selected: false
    // A second action in the corner, shown on hover (forget). While it is
    // `armed` — asked for once, waiting to be confirmed — the note says so.
    property string actionIcon: ""
    property string actionNote: ""
    property bool armed: false

    readonly property bool hovered: hover.hovered
    readonly property bool linked: tone === "linked"
    readonly property bool failed: tone === "failed"
    readonly property bool lit: interactive && (hovered || selected)
    readonly property color ink: linked ? Theme.accentText : Theme.text
    readonly property point center: Qt.point(x + width / 2, y + height / 2)
    // The slot's place on the ellipse; animated so that cards glide when the list changes.
    property real bearing: 2 * Math.PI * slot / Math.max(1, slots)
    readonly property point place: orbit.point(orbit.turn + bearing, ring)
    // 0 → 1 as the card pops in.
    property real pop: 0
    // The card leans in under the pointer and gives a little when pressed.
    property real emphasis: mouse.pressed ? 0.96 : lit ? 1.06 : 1

    signal clicked
    signal actionClicked

    x: place.x - width / 2
    y: place.y - height / 2
    width: Theme.px(176)
    height: Theme.px(58)
    scale: pop * emphasis

    onHoveredChanged: orbit.hold(hovered)
    Component.onDestruction: {
        if (hovered)
            orbit.hold(false);
    }

    Behavior on bearing {
        NumberAnimation { duration: 800; easing.type: Easing.OutExpo }
    }
    Behavior on emphasis {
        NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic }
    }

    // Cards appear one after the other around the ring.
    SequentialAnimation on pop {
        PauseAnimation { duration: Math.max(0, root.slot) * 35 }
        NumberAnimation { to: 1; duration: Theme.slow; easing.type: Easing.OutBack }
    }

    HoverHandler {
        id: hover
    }

    ClippingRectangle {
        anchors.fill: parent
        radius: Theme.radius
        color: root.failed ? Theme.mix(Theme.surface0, Theme.red, 0.22) : root.lit ? Theme.surface1 : Theme.surface0
        border.width: root.selected ? Theme.px(2) : 1
        border.color: root.failed ? Theme.alpha(Theme.red, 0.7) : root.selected ? Theme.text : root.lit || root.tone !== "" ? Theme.alpha(root.hue, 0.6) : Theme.border

        Behavior on color {
            ColorAnimation { duration: Theme.fast }
        }
        Behavior on border.color {
            ColorAnimation { duration: Theme.fast }
        }

        // Liquid in the side's hue: sloshing while connecting, full once in use.
        Wave {
            anchors.fill: parent
            level: root.linked ? 1 : root.tone === "busy" ? 0.5 : 0
            color: root.linked ? root.hue : Theme.alpha(root.hue, 0.3)

            Behavior on level {
                NumberAnimation { duration: Theme.slow; easing.type: Easing.OutCubic }
            }
        }

        Item {
            id: badge

            x: Theme.px(12)
            width: Theme.px(26)
            height: parent.height

            Icon {
                anchors.centerIn: parent
                visible: root.tone !== "busy"
                text: root.icon
                size: 21
                color: root.linked ? root.ink : root.failed ? Theme.red : root.hue
            }

            Spinner {
                anchors.centerIn: parent
                visible: root.tone === "busy"
                color: root.hue
            }
        }

        Column {
            anchors.left: badge.right
            anchors.leftMargin: Theme.px(10)
            anchors.right: parent.right
            anchors.rightMargin: action.visible ? Theme.px(38) : Theme.px(12)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.px(1)

            Txt {
                id: name

                width: parent.width
                visible: !scrollingName.visible
                text: root.title
                size: 13
                bold: true
                color: root.ink
                fontSizeMode: root.fitTitle ? Text.HorizontalFit : Text.FixedSize
                minimumPixelSize: Theme.px(10)
            }

            // A name that does not fit scrolls while the pointer is on the card.
            Marquee {
                id: scrollingName

                width: parent.width
                height: name.height
                visible: root.hovered && name.truncated
                text: root.title
                size: 13
                bold: true
                color: root.ink
            }

            Txt {
                width: parent.width
                text: root.armed ? root.actionNote : root.hovered && root.hint !== "" && root.tone !== "busy" ? root.hint : root.note
                size: 10
                color: root.armed || root.failed ? Theme.red : root.linked ? Theme.alpha(root.ink, 0.75) : root.lit ? root.hue : Theme.subtext
            }
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        enabled: root.interactive
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    IconBtn {
        id: action

        anchors.right: parent.right
        anchors.rightMargin: Theme.px(8)
        anchors.verticalCenter: parent.verticalCenter
        visible: root.actionIcon !== "" && root.hovered
        icon: root.actionIcon
        size: 28
        iconColor: root.ink
        active: root.armed
        accentColor: Theme.red
        onClicked: root.actionClicked()
    }
}
