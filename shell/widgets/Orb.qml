import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs.core

// A round gauge filled with liquid, with a label that stays readable above and
// below the surface. The hero of the volume and network popups.
Item {
    id: root

    property real level: 0                      // 0 … 1
    property string text: ""
    property color color: Theme.accent
    property real size: 22                      // label size, design units
    // A slow ring pulsing outwards, for "active" states.
    property bool pulsing: false

    implicitWidth: Theme.px(110)
    implicitHeight: Theme.px(110)

    Rectangle {
        id: pulse

        anchors.centerIn: parent
        width: parent.width
        height: parent.height
        radius: width / 2
        color: "transparent"
        border.width: Theme.px(2)
        border.color: root.color
        opacity: 0

        ParallelAnimation {
            running: root.pulsing && root.visible
            loops: Animation.Infinite

            NumberAnimation { target: pulse; property: "scale"; from: 1; to: 1.3; duration: 2200; easing.type: Easing.OutCubic }
            NumberAnimation { target: pulse; property: "opacity"; from: 0.5; to: 0; duration: 2200; easing.type: Easing.OutCubic }
        }
    }

    // The label is drawn twice — on the glass and, in the contrast colour, on
    // the liquid — each masked to its part by the liquid itself, so that it
    // stays crisp right at the moving surface.
    component Label: Item {
        id: face

        property color ink: Theme.text
        // Show the part under the liquid (true) or the part above it (false).
        property bool submerged: false

        anchors.fill: parent
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: wave
            maskInverted: !face.submerged
        }

        Txt {
            anchors.centerIn: parent
            text: root.text
            size: root.size
            bold: true
            color: face.ink
        }
    }

    ClippingRectangle {
        anchors.fill: parent
        radius: width / 2
        color: Theme.alpha(Theme.surface0, 0.8)
        border.width: 1
        border.color: Theme.alpha(root.color, 0.35)

        Wave {
            id: wave

            anchors.fill: parent
            level: root.level
            color: root.color
            amplitude: Theme.px(4)
            // Rendered to a texture so that it can mask the labels.
            layer.enabled: true

            Behavior on level {
                NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic }
            }
        }

        Label {}

        Label {
            ink: Theme.accentText
            submerged: true
        }
    }
}
