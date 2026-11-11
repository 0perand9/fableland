import QtQuick
import QtQuick.Shapes
import qs.core

// A small history graph: a line over a soft fill. The newest sample sits at
// the right edge; older ones trail off to the left until `capacity` samples
// span the whole width.
Item {
    id: root

    property var values: []             // oldest first
    property real ceiling: 100          // the value drawn at the very top
    property int capacity: 60
    property color color: Theme.accent
    property bool filled: true

    readonly property real stroke: 1.5 * Theme.scale
    readonly property var line: {
        const count = values.length, points = [];
        const step = width / Math.max(1, capacity - 1);
        // Half a stroke of headroom, so a full-scale sample is not cut off.
        const usable = height - stroke;
        for (let i = 0; i < count; i++) {
            const level = Math.max(0, Math.min(1, values[i] / ceiling));
            points.push(Qt.point(width - (count - 1 - i) * step, stroke / 2 + usable * (1 - level)));
        }
        return points;
    }
    readonly property var area: line.length > 1 ? [Qt.point(line[0].x, height)].concat(line, [Qt.point(width, height)]) : []

    Shape {
        anchors.fill: parent
        visible: root.line.length > 1
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: "transparent"
            fillGradient: LinearGradient {
                y2: root.height

                GradientStop { position: 0; color: Theme.alpha(root.color, root.filled ? 0.3 : 0) }
                GradientStop { position: 1; color: Theme.alpha(root.color, 0) }
            }

            PathPolyline {
                path: root.area
            }
        }

        ShapePath {
            strokeColor: root.color
            strokeWidth: root.stroke
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            PathPolyline {
                path: root.line
            }
        }
    }
}
