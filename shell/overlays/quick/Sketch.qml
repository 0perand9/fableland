import QtQuick
import QtQuick.Shapes
import qs.core

// The drawing: marks of ink, the pointer that makes and erases them, and the
// history that undoes it all. Marks are scene items, not pixels — a stroke
// costs the same on any screen size and nothing is ever repainted.
Item {
    id: sketch

    // pen | marker | line | arrow | rect | ellipse | eraser
    property string tool: "pen"
    property color ink: Theme.red
    // The current tool's stroke width — for the eraser its diameter — in real pixels.
    property real thickness: 4

    readonly property bool canUndo: applied > 0
    readonly property bool canRedo: applied < steps
    readonly property bool blank: inked === 0

    // Each step of the history lists the marks it added and those it took away;
    // undo and redo only flip which of them show.
    property var history: []
    property int steps: 0           // history.length, where bindings can see it
    property int applied: 0         // how many steps are in effect
    property int inked: 0           // marks showing

    // The gesture under way: the tool it began with, where it began, the mark
    // it is drawing or the marks it has erased so far.
    property string gesture: ""
    readonly property bool freehand: gesture === "pen" || gesture === "marker"
    property point origin
    property point last
    property var live: null
    property var erased: []

    // The wheel asks for a thinner (-1) or thicker (+1) stroke.
    signal nudged(int steps)

    function commit(added, removed) {
        // A new step replaces everything that had been undone; marks only those steps knew are gone for good.
        for (const step of history.splice(applied))
            for (const mark of step.added)
                mark.destroy();
        history.push({ added: added, removed: removed });
        applied = steps = history.length;
        inked += added.length;
    }

    function flip(step, forward) {
        for (const mark of step.added)
            mark.shown = forward;
        for (const mark of step.removed)
            mark.shown = !forward;
        inked += (forward ? 1 : -1) * (step.added.length - step.removed.length);
    }

    function undo() {
        if (gesture === "" && applied > 0)
            flip(history[--applied], false);
    }

    function redo() {
        if (gesture === "" && applied < steps)
            flip(history[applied++], true);
    }

    function clear() {
        const marks = showing();
        if (gesture !== "" || marks.length === 0)
            return;
        take(marks);
        commit([], marks);
    }

    function showing() {
        const marks = [];
        for (const layer of [highlights, lines])
            for (let i = 0; i < layer.children.length; i++)
                if (layer.children[i].shown)
                    marks.push(layer.children[i]);
        return marks;
    }

    function take(marks) {
        for (const mark of marks)
            mark.shown = false;
        inked -= marks.length;
    }

    // The outline of a figure spanned from `a` to `b`, as polylines.
    function outline(kind, a, b) {
        switch (kind) {
        case "rect":
            return [[a, Qt.point(b.x, a.y), b, Qt.point(a.x, b.y), a]];
        case "ellipse": {
            const cx = (a.x + b.x) / 2, cy = (a.y + b.y) / 2, rx = Math.abs(b.x - a.x) / 2, ry = Math.abs(b.y - a.y) / 2;
            const points = [], sides = 96;
            for (let i = 0; i <= sides; i++)
                points.push(Qt.point(cx + rx * Math.cos(2 * Math.PI * i / sides), cy + ry * Math.sin(2 * Math.PI * i / sides)));
            return [points];
        }
        case "arrow": {
            // The shaft, and the two barbs of the head meeting at its tip.
            const length = Math.hypot(b.x - a.x, b.y - a.y), heading = Math.atan2(b.y - a.y, b.x - a.x);
            const head = Math.min(length * 0.5, thickness * 3 + Theme.px(10));
            const barb = side => Qt.point(b.x - head * Math.cos(heading + side * 0.5), b.y - head * Math.sin(heading + side * 0.5));
            return [[a, b], [barb(1), b, barb(-1)]];
        }
        default:
            return [[a, b]];
        }
    }

    function begin(x, y) {
        gesture = tool;
        origin = last = Qt.point(x, y);
        if (gesture === "eraser") {
            erased = [];
            erase(x, y);
            return;
        }
        // Highlighter strokes go on their own see-through layer, under the lines.
        live = stroke.createObject(gesture === "marker" ? highlights : lines, {
            color: ink,
            thickness: thickness,
            joinStyle: freehand ? ShapePath.BevelJoin : ShapePath.MiterJoin
        });
        // A click with the pen already leaves a dot; a figure waits to be pulled open.
        if (freehand)
            live.extend(x, y);
    }

    function drag(x, y) {
        if (gesture === "eraser")
            erase(x, y);
        else if (freehand)
            live.extend(x, y);
        else if (live)
            // A copy of the origin: a point read from a property stays tied to that property.
            live.reshape(outline(gesture, Qt.point(origin.x, origin.y), Qt.point(x, y)));
        last = Qt.point(x, y);
    }

    function finish() {
        if (gesture === "eraser") {
            if (erased.length > 0)
                commit([], erased);
        } else if (live) {
            // A figure that was never pulled open is a slip of the finger, not a mark.
            if (live.vertices.length === 0)
                live.destroy();
            else
                commit([live], []);
        }
        live = null;
        erased = [];
        gesture = "";
    }

    // Take away every mark the eraser touches on its way from `last` to (x, y).
    function erase(x, y) {
        const reach = thickness / 2;
        const hops = Math.max(1, Math.ceil(Math.hypot(x - last.x, y - last.y) / reach));
        const marks = showing();
        for (let hop = 1; hop <= hops; hop++) {
            const px = last.x + (x - last.x) * hop / hops, py = last.y + (y - last.y) * hop / hops;
            const hit = marks.filter(mark => mark.shown && mark.touches(px, py, reach));
            take(hit);
            erased = erased.concat(hit);
        }
    }

    Component {
        id: stroke

        Mark {}
    }

    // One shared layer keeps overlapping highlights from adding up into opaque blotches.
    Item {
        id: highlights

        anchors.fill: parent
        opacity: 0.4
        layer.enabled: children.length > 0
    }

    Item {
        id: lines

        anchors.fill: parent
    }

    // The size of the eraser, or of the stroke while the wheel changes it.
    Rectangle {
        visible: (sketch.tool === "eraser" && pointer.containsMouse) || sizeShown.running
        x: sketch.last.x - width / 2
        y: sketch.last.y - height / 2
        width: sketch.thickness
        height: width
        radius: width / 2
        color: Theme.alpha(sketch.tool === "eraser" ? Theme.text : sketch.ink, 0.25)
        border.width: 1
        border.color: Theme.alpha(Theme.text, 0.8)
    }

    Timer {
        id: sizeShown

        interval: 700
    }

    MouseArea {
        id: pointer

        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        // Only the eraser needs to follow a pointer that is not pressed.
        hoverEnabled: sketch.tool === "eraser"
        cursorShape: Qt.CrossCursor
        onPressed: mouse => sketch.begin(mouse.x, mouse.y)
        onPositionChanged: mouse => {
            if (pressed)
                sketch.drag(mouse.x, mouse.y);
            else
                sketch.last = Qt.point(mouse.x, mouse.y);
        }
        onReleased: sketch.finish()
        onCanceled: sketch.finish()
        onWheel: wheel => {
            if (!pressed) {
                sketch.last = Qt.point(wheel.x, wheel.y);
                sketch.nudged(wheel.angleDelta.y > 0 ? 1 : -1);
                sizeShown.restart();
            }
        }
    }
}
