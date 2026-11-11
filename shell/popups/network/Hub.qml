import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs.core
import qs.widgets

// The centre of the network popup: a liquid orb for the connection in use,
// filled to its signal or battery level, or rippling while there is none.
// Holding it drains the liquid; once empty, the connection is dropped.
Core {
    id: root

    // The connection on show (see Side.links), or null.
    property var link: null
    property color hue: Theme.accent
    // Shown while nothing is linked.
    property string idleIcon: ""
    property string idleText: ""
    // With several links the hub shows one; a click steps to the next.
    property int linkCount: 0
    property int linkIndex: 0

    readonly property bool linked: link !== null
    // A link can be dropped while it is still coming up, too.
    readonly property bool holdable: linked && link.state !== "disconnecting"
    readonly property bool danger: holdable && (mouse.containsMouse || drained > 0)
    property color tint: danger ? Theme.red : hue
    // How full the orb is. The weakest signal still leaves a puddle, and the
    // strongest some air for the surface to move in.
    property real fill: linked ? 0.15 + 0.75 * Math.max(0, Math.min(1, link.level)) : 0
    // 0 → 1 while a hold drains the orb.
    property real drained: 0
    readonly property string caption: !linked ? idleText
        : link.state === "disconnecting" || drained >= 1 ? "Disconnecting…"
        : drained > 0 ? "Keep holding…"
        : link.state === "connecting" ? (mouse.containsMouse ? "Hold to cancel" : "Connecting…")
        : mouse.containsMouse ? "Hold to disconnect" : "Connected"

    signal dropRequested
    signal stepRequested

    implicitWidth: Theme.px(200)
    implicitHeight: Theme.px(200)

    Behavior on fill {
        NumberAnimation { duration: Theme.slow; easing.type: Easing.OutCubic }
    }
    Behavior on tint {
        ColorAnimation { duration: Theme.normal }
    }

    states: State {
        name: "holding"
        when: mouse.pressed && root.holdable

        PropertyChanges { root.drained: 1 }
    }
    transitions: [
        Transition {
            to: "holding"

            SequentialAnimation {
                NumberAnimation { property: "drained"; duration: 900; easing.type: Easing.InOutSine }
                ScriptAction { script: root.dropRequested() }
            }
        },
        Transition {
            from: "holding"

            NumberAnimation { property: "drained"; duration: Theme.normal; easing.type: Easing.OutCubic }
        }
    ]

    // What the orb says. It is drawn twice — on the glass and, in the contrast
    // colour, on the liquid — each masked to its part by the liquid itself, so
    // that small text stays crisp right at the moving surface.
    component Label: Item {
        id: face

        property color ink: Theme.text
        // Show the part under the liquid (true) or the part above it (false).
        property bool submerged: false

        anchors.fill: parent
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: liquid
            maskInverted: !face.submerged
        }

        Column {
            anchors.centerIn: parent
            width: parent.width - Theme.px(44)
            spacing: Theme.px(4)

            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.linked ? root.link.icon : root.idleIcon
                size: 40
                color: face.ink
            }

            Txt {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                visible: root.linked
                text: root.linked ? root.link.title : ""
                size: 15
                bold: true
                color: face.ink
                fontSizeMode: Text.HorizontalFit
                minimumPixelSize: Theme.px(11)
            }

            Txt {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: root.caption
                size: 11
                color: Theme.alpha(face.ink, 0.8)
            }

            // One dot per link, when there are several.
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.linkCount > 1
                spacing: Theme.px(5)

                Repeater {
                    model: root.linkCount

                    Rectangle {
                        required property int index

                        width: Theme.px(6)
                        height: width
                        radius: width / 2
                        color: Theme.alpha(face.ink, index === root.linkIndex ? 1 : 0.35)
                    }
                }
            }
        }
    }

    // A soft halo breathing behind a live connection.
    Rectangle {
        id: halo

        anchors.centerIn: parent
        width: parent.width + Theme.px(36)
        height: width
        radius: width / 2
        color: Theme.alpha(root.tint, 0.14)
        visible: root.linked

        SequentialAnimation on scale {
            running: halo.visible
            loops: Animation.Infinite

            NumberAnimation { to: 1.08; duration: 2000; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1; duration: 2000; easing.type: Easing.InOutSine }
        }
    }

    // Ripples running outwards while looking for something to connect to.
    Repeater {
        model: 3

        Rectangle {
            id: ripple

            required property int index

            anchors.centerIn: parent
            width: root.width
            height: width
            radius: width / 2
            color: "transparent"
            border.width: Theme.px(2)
            border.color: root.hue
            visible: !root.linked
            opacity: 0

            SequentialAnimation {
                running: ripple.visible
                loops: Animation.Infinite

                PauseAnimation { duration: ripple.index * 800 }
                ParallelAnimation {
                    NumberAnimation { target: ripple; property: "scale"; from: 1; to: 1.5; duration: 2400; easing.type: Easing.OutSine }
                    NumberAnimation { target: ripple; property: "opacity"; from: 0.45; to: 0; duration: 2400; easing.type: Easing.OutSine }
                }
                PauseAnimation { duration: (2 - ripple.index) * 800 }
            }
        }
    }

    ClippingRectangle {
        id: glass

        anchors.fill: parent
        radius: width / 2
        color: Theme.mix(Theme.base, Theme.surface0, 0.8)
        border.width: 1
        border.color: Theme.alpha(root.tint, root.linked ? 0.5 : 0.3)

        Wave {
            id: liquid

            anchors.fill: parent
            level: root.fill * (1 - root.drained)
            color: root.tint
            amplitude: Theme.px(5)
            // Rendered to a texture so that it can mask the labels.
            layer.enabled: true
        }

        Label {
            ink: root.linked ? Theme.text : root.hue
        }

        Label {
            ink: Theme.accentText
            submerged: true
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        enabled: root.linked
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        // A hold that got anywhere is not a click.
        onClicked: {
            if (root.drained < 0.25)
                root.stepRequested();
        }
    }
}
