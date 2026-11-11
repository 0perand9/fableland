import QtQuick
import QtQuick.Shapes
import qs.core

// A dotted line of light flowing from the hub to one of its facts. It leaves
// the hub at its rim and stops at the edge of the card.
Shape {
    id: root

    // The hub's centre and radius.
    property point from
    property real clearance: 0
    // The card's centre and size.
    property point to
    property size toSize
    property color hue: Theme.accent

    readonly property real distance: Math.hypot(to.x - from.x, to.y - from.y)
    readonly property real ux: distance > 0 ? (to.x - from.x) / distance : 0
    readonly property real uy: distance > 0 ? (to.y - from.y) / distance : 0
    // How far before the card's centre the line meets the card's edge.
    readonly property real cut: Math.min(toSize.width / 2 / Math.max(1e-6, Math.abs(ux)), toSize.height / 2 / Math.max(1e-6, Math.abs(uy)))
    readonly property bool drawn: distance > clearance + cut

    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        id: line

        strokeColor: root.drawn ? Theme.alpha(root.hue, 0.6) : "transparent"
        strokeWidth: Theme.px(2)
        strokeStyle: ShapePath.DashLine
        dashPattern: [1, 3]
        capStyle: ShapePath.RoundCap
        fillColor: "transparent"
        startX: root.from.x + root.ux * root.clearance
        startY: root.from.y + root.uy * root.clearance

        PathLine {
            x: root.to.x - root.ux * root.cut
            y: root.to.y - root.uy * root.cut
        }

        // The dots travel outwards, one dash period per cycle.
        NumberAnimation on dashOffset {
            from: 4
            to: 0
            duration: 700
            loops: Animation.Infinite
            running: root.visible
        }
    }
}
