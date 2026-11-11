import QtQuick
import QtQuick.Shapes
import qs.core

// The slowly turning ellipses that satellites ride around the hub, drawn as
// faint radar rings. The hub sits in the middle of this item.
Item {
    id: root

    property color hue: Theme.accent
    property bool running: visible
    // The current rotation, in radians.
    property real turn: 0
    // Satellites under the pointer hold the orbit still so they are easy to hit.
    property int holds: 0

    // Seconds per revolution.
    readonly property real period: 150
    // Radii in design units. Satellites ride the last two: facts on the inner
    // one, peers alternate between both so that neighbours do not collide.
    readonly property var rings: [Qt.size(196, 126), Qt.size(280, 180), Qt.size(340, 225)]
    readonly property point center: Qt.point(width / 2, height / 2)

    function hold(on) {
        holds += on ? 1 : -1;
    }

    // Where a satellite at `angle` on riding ring `ring` (0 inner, 1 outer) is centred.
    function point(angle, ring) {
        const radii = rings[ring + 1];
        return Qt.point(center.x + Math.cos(angle) * Theme.px(radii.width), center.y + Math.sin(angle) * Theme.px(radii.height));
    }

    // Advancing by frame time (rather than animating 0 → 2π) lets the orbit
    // stop and carry on from where it was.
    FrameAnimation {
        running: root.running && root.holds === 0
        onTriggered: root.turn = (root.turn + frameTime * 2 * Math.PI / root.period) % (2 * Math.PI)
    }

    Repeater {
        model: root.rings

        Shape {
            id: ring

            required property size modelData
            required property int index

            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: Theme.alpha(root.hue, 0.2 - ring.index * 0.05)
                strokeWidth: 1
                fillColor: "transparent"

                PathAngleArc {
                    centerX: root.center.x
                    centerY: root.center.y
                    radiusX: Theme.px(ring.modelData.width)
                    radiusY: Theme.px(ring.modelData.height)
                    startAngle: 0
                    sweepAngle: 360
                }
            }
        }
    }
}
