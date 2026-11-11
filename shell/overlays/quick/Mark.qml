import QtQuick
import QtQuick.Shapes

// One mark of ink: a polyline with round ends. It is drawn as a chain of short
// shapes, so that extending a long freehand stroke re-tessellates only its
// last link — drawing stays immediate however long the stroke gets.
Item {
    id: mark

    property color color
    property real thickness: 4          // real pixels
    // How the line turns at its vertices. Bevelled suits the many shallow turns
    // of freehand; figures want their corners mitred. (Round joins are out: the
    // curve renderer leaves pinholes between the segments of a dense polyline.)
    property int joinStyle: ShapePath.BevelJoin
    // Undoing and erasing only hide a mark; redo brings it back.
    property bool shown: true

    // Every vertex and the box around them, for hit tests.
    property var vertices: []
    property var box: null

    // Vertices per link, and the least movement worth a new vertex.
    readonly property int linkLength: 48
    readonly property real minStep: 1.5
    // The link still growing, and its vertices.
    property var tail: null
    property var tailPath: []

    function enclose(point) {
        if (!box)
            box = { left: point.x, top: point.y, right: point.x, bottom: point.y };
        box.left = Math.min(box.left, point.x);
        box.top = Math.min(box.top, point.y);
        box.right = Math.max(box.right, point.x);
        box.bottom = Math.max(box.bottom, point.y);
    }

    // Freehand: carry the line on to (x, y).
    function extend(x, y) {
        const count = vertices.length;
        if (count > 0) {
            const last = vertices[count - 1];
            if (Math.abs(x - last.x) < minStep && Math.abs(y - last.y) < minStep)
                return;
        }
        const point = Qt.point(x, y);
        if (!tail || tailPath.length >= linkLength) {
            // A new link starts on the last vertex of the one before, so the line has no gap.
            tailPath = count > 0 ? [vertices[count - 1]] : [];
            tail = link.createObject(mark);
        }
        vertices.push(point);
        tailPath.push(point);
        // A lone vertex shows as a dot: a line too short to see, with round ends.
        tail.path = tailPath.length > 1 ? tailPath : [point, Qt.point(x + 0.01, y)];
        enclose(point);
    }

    // A figure: replace the whole outline, given as one or more polylines.
    // Each gets a link of its own; for hit tests they count as one line on end.
    function reshape(outline) {
        while (children.length < outline.length)
            link.createObject(mark);
        outline.forEach((points, i) => children[i].path = points);
        vertices = [].concat(...outline);
        box = null;
        for (const point of vertices)
            enclose(point);
    }

    // Whether a disc of radius `reach` around (x, y) touches the line.
    function touches(x, y, reach) {
        const r = reach + thickness / 2;
        if (!box || x < box.left - r || x > box.right + r || y < box.top - r || y > box.bottom + r)
            return false;
        let ax = vertices[0].x, ay = vertices[0].y;
        for (let i = 1; i <= vertices.length; i++) {
            // The last round measures to the final vertex itself, which also covers a lone dot.
            const b = vertices[Math.min(i, vertices.length - 1)];
            const dx = b.x - ax, dy = b.y - ay, length2 = dx * dx + dy * dy;
            const t = length2 > 0 ? Math.max(0, Math.min(1, ((x - ax) * dx + (y - ay) * dy) / length2)) : 0;
            const nx = ax + t * dx - x, ny = ay + t * dy - y;
            if (nx * nx + ny * ny <= r * r)
                return true;
            ax = b.x;
            ay = b.y;
        }
        return false;
    }

    visible: shown

    Component {
        id: link

        Shape {
            property alias path: line.path

            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: mark.color
                strokeWidth: mark.thickness
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: mark.joinStyle

                PathPolyline {
                    id: line
                }
            }
        }
    }
}
