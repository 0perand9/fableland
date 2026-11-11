import QtQuick

// The rectangle being selected on the capture overlay and the ways a pointer
// or the keyboard can change it. Pure geometry: SelectionView draws it.
QtObject {
    id: root

    // The area the selection lives in.
    property real boundsWidth: 0
    property real boundsHeight: 0

    // Two opposite corners. A drag pulls (x2, y2), which may cross over (x1, y1).
    property real x1: 0
    property real y1: 0
    property real x2: 0
    property real y2: 0

    readonly property real x: Math.min(x1, x2)
    readonly property real y: Math.min(y1, y2)
    readonly property real width: Math.abs(x2 - x1)
    readonly property real height: Math.abs(y2 - y1)
    // Anything smaller is a slip of the hand, not a selection.
    readonly property real minSize: 10
    readonly property bool exists: width >= minSize && height >= minSize
    readonly property bool full: exists && width >= boundsWidth && height >= boundsHeight
    readonly property rect area: Qt.rect(x, y, width, height)

    // What the drag in progress does: "new" draws a fresh rectangle, "move"
    // carries it around, and compass letters ("n", "se", ...) pull those edges.
    property string grip: ""
    readonly property bool dragging: grip !== ""

    // Bookkeeping of the drag in progress.
    property bool pullX: false
    property bool pullY: false
    // Pointer position relative to the corner being pulled, so that it does not jump.
    property point pullOffset: Qt.point(0, 0)
    property point pressedAt: Qt.point(0, 0)
    property rect pressedArea: Qt.rect(0, 0, 0, 0)
    // What toggleFull() goes back to.
    property rect beforeFull: Qt.rect(0, 0, 0, 0)

    function clamp(value, max) {
        return Math.max(0, Math.min(max, value));
    }

    function set(rect) {
        x1 = rect.x;
        y1 = rect.y;
        x2 = rect.x + rect.width;
        y2 = rect.y + rect.height;
        fit();
    }

    function clear() {
        x2 = x1;
        y2 = y1;
    }

    // Which grip a press at this point would take. `reach` is how far from an
    // edge still counts as on it.
    function gripAt(px, py, reach) {
        if (!exists)
            return "new";
        const left = Math.abs(px - x), right = Math.abs(px - x - width);
        const top = Math.abs(py - y), bottom = Math.abs(py - y - height);
        const withinX = px >= x - reach && px <= x + width + reach;
        const withinY = py >= y - reach && py <= y + height + reach;
        const vertical = !withinX ? "" : top <= reach && top <= bottom ? "n" : bottom <= reach ? "s" : "";
        const horizontal = !withinY ? "" : left <= reach && left <= right ? "w" : right <= reach ? "e" : "";
        return (vertical + horizontal) || "new";
    }

    function press(px, py, withGrip) {
        // Plain numbers: a rect read from a property would follow the changes below.
        const left = x, top = y, right = x + width, bottom = y + height;
        grip = withGrip;
        pressedAt = Qt.point(px, py);
        pressedArea = Qt.rect(left, top, right - left, bottom - top);
        if (grip === "new") {
            x1 = x2 = clamp(px, boundsWidth);
            y1 = y2 = clamp(py, boundsHeight);
            pullX = pullY = true;
            pullOffset = Qt.point(0, 0);
        } else if (grip !== "move") {
            // Put the corner that moves in (x2, y2) and the one that stays in (x1, y1).
            const west = grip.includes("w"), north = grip.includes("n");
            pullX = west || grip.includes("e");
            pullY = north || grip.includes("s");
            x1 = west ? right : left;
            x2 = west ? left : right;
            y1 = north ? bottom : top;
            y2 = north ? top : bottom;
            pullOffset = Qt.point(px - x2, py - y2);
        }
    }

    function drag(px, py) {
        if (grip === "move") {
            moveTo(pressedArea.x + px - pressedAt.x, pressedArea.y + py - pressedAt.y, pressedArea.width, pressedArea.height);
            return;
        }
        if (pullX)
            x2 = clamp(px - pullOffset.x, boundsWidth);
        if (pullY)
            y2 = clamp(py - pullOffset.y, boundsHeight);
    }

    function release() {
        grip = "";
        if (!exists)
            clear();
    }

    // Place a rectangle of this size as close to (px, py) as the bounds allow.
    function moveTo(px, py, w, h) {
        x1 = clamp(px, boundsWidth - w);
        y1 = clamp(py, boundsHeight - h);
        x2 = x1 + w;
        y2 = y1 + h;
    }

    function nudge(dx, dy) {
        if (exists)
            moveTo(x + dx, y + dy, width, height);
    }

    // The whole area, or back to what was selected before.
    function toggleFull() {
        if (full) {
            set(beforeFull);
        } else {
            beforeFull = area;
            set(Qt.rect(0, 0, boundsWidth, boundsHeight));
        }
    }

    // Keep a selection made for other bounds (a remembered one, another screen)
    // inside these, once they are known.
    function fit() {
        if (dragging || boundsWidth <= 0 || boundsHeight <= 0)
            return;
        x1 = clamp(x1, boundsWidth);
        y1 = clamp(y1, boundsHeight);
        x2 = clamp(x2, boundsWidth);
        y2 = clamp(y2, boundsHeight);
    }

    onBoundsWidthChanged: fit()
    onBoundsHeightChanged: fit()
}
