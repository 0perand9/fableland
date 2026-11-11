import QtQuick
import QtQuick.Shapes
import qs.core

// A circular gauge. Put content in the middle with anchors.centerIn.
Item {
    id: root

    property real value: 0                       // 0 … 1
    property real thickness: 6                   // design units
    property color color: Theme.accent
    property color trackColor: Theme.alpha(Theme.surface2, 0.5)
    property real startAngle: -90
    property bool rounded: true

    readonly property real stroke: Theme.px(thickness)
    readonly property real arcRadius: Math.max(0, (Math.min(width, height) - stroke) / 2)

    implicitWidth: Theme.px(64)
    implicitHeight: Theme.px(64)

    Behavior on value {
        NumberAnimation { duration: Theme.slow; easing.type: Easing.OutCubic }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.trackColor
            strokeWidth: root.stroke
            fillColor: "transparent"

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.arcRadius
                radiusY: root.arcRadius
                startAngle: 0
                sweepAngle: 360
            }
        }

        ShapePath {
            strokeColor: root.value > 0 ? root.color : "transparent"
            strokeWidth: root.stroke
            fillColor: "transparent"
            capStyle: root.rounded ? ShapePath.RoundCap : ShapePath.FlatCap

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.arcRadius
                radiusY: root.arcRadius
                startAngle: root.startAngle
                sweepAngle: 360 * Math.max(0, Math.min(1, root.value))
            }
        }
    }
}
