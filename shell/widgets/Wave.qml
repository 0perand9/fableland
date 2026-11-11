import QtQuick
import QtQuick.Shapes
import qs.core

// A liquid that fills its box from the bottom, with a moving surface.
// Used for hold-to-confirm buttons and level gauges.
Item {
    id: root

    property real level: 0.5                    // 0 empty … 1 full
    property color color: Theme.accent
    property real amplitude: Theme.px(3)
    property real wavelength: Theme.px(90)
    property bool running: visible && level > 0 && level < 1
    property real phase: 0

    readonly property var surface: {
        const top = height * (1 - level);
        // The surface calms down as the box gets full or empty.
        const amp = amplitude * Math.min(1, 4 * level * (1 - level) + 0.25);
        const count = Math.max(2, Math.min(48, Math.ceil(width / Theme.px(8))));
        const pts = [Qt.point(0, height)];
        for (let i = 0; i <= count; i++) {
            const x = width * i / count;
            pts.push(Qt.point(x, top + amp * Math.sin(x / wavelength * 2 * Math.PI + phase)));
        }
        pts.push(Qt.point(width, height));
        return pts;
    }

    Shape {
        anchors.fill: parent
        visible: root.level > 0
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: "transparent"
            fillColor: root.color

            PathPolyline {
                path: root.surface
            }
        }
    }

    FrameAnimation {
        running: root.running
        onTriggered: root.phase = (root.phase + frameTime * 4) % (2 * Math.PI)
    }
}
