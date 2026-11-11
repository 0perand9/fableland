import QtQuick
import qs.core
import qs.widgets
import "layout.js" as Layout

// The monitors drawn to scale where they sit in the layout. A dragged monitor
// slides around the others: it always touches one of them and snaps where
// edges or centres line up.
Item {
    id: root

    // The layout being edited (see layout.js for the shape of a monitor).
    property var monitors: []
    // Name of the monitor whose settings are shown.
    property string selected: ""

    signal picked(string name)
    // A monitor was dragged to a new spot (layout pixels), then let go.
    signal moved(string name, real x, real y)
    signal dropped(string name)

    readonly property int margin: Theme.px(26)
    readonly property int cell: Theme.px(26)
    // The drag in progress: { name, view, from, press } — the view it is seen
    // through, the monitor's corner when it began and where the pointer was.
    property var held: null
    // Layout pixels → canvas pixels: { zoom, x, y }. Normally it frames the
    // layout. During a drag it stays put — a view that followed the monitor
    // would move the ground under the pointer — and is wide enough for every
    // spot the monitor could be dropped on.
    readonly property var view: held ? held.view : frame(Layout.bounds(monitors), null, null)

    // The view that shows the layout rectangle `area`. Given a layout point
    // `pin` and a canvas point `under`, the pin stays under that point as far
    // as the fit leaves room, so that what the pointer holds does not jump away.
    function frame(area, pin, under) {
        if (!(area.w > 0 && area.h > 0))
            return { zoom: 1, x: 0, y: 0 };
        const zoom = Math.min((width - 2 * margin) / area.w, (height - 2 * margin) / area.h);
        const along = (canvas, start, extent, pinned, target) => {
            const low = canvas - margin - (start + extent) * zoom, high = margin - start * zoom;
            return pin ? Math.max(low, Math.min(high, target - pinned * zoom)) : (low + high) / 2;
        };
        return { zoom: zoom, x: along(width, area.x, area.w, pin?.x, under?.x), y: along(height, area.y, area.h, pin?.y, under?.y) };
    }

    function grab(name, press) {
        const box = Layout.rect(monitors.find(m => m.name === name));
        const others = Layout.bounds(monitors.filter(m => m.name !== name));
        const reachable = { x: others.x - box.w, y: others.y - box.h, w: others.w + 2 * box.w, h: others.h + 2 * box.h };
        const pin = Qt.point((press.x - view.x) / view.zoom, (press.y - view.y) / view.zoom);
        held = { name: name, view: frame(reachable, pin, press), from: Qt.point(box.x, box.y), press: press };
    }

    // The pointer moved to `at`: put the held monitor on the nearest spot against the others.
    function drag(at) {
        const wanted = Qt.point(held.from.x + (at.x - held.press.x) / view.zoom, held.from.y + (at.y - held.press.y) / view.zoom);
        const others = monitors.filter(m => m.name !== held.name).map(Layout.rect);
        const spot = Layout.glue(Layout.rect(monitors.find(m => m.name === held.name)), wanted, others, Theme.px(12) / view.zoom);
        if (spot)
            root.moved(held.name, Math.round(spot.x), Math.round(spot.y));
    }

    function release() {
        if (!held)
            return;
        const name = held.name;
        held = null;
        root.dropped(name);
    }

    KeyedModel {
        id: tiles

        source: root.monitors
        key: "name"
    }

    // A faint grid to arrange on: the upright lines first, then the level ones.
    Repeater {
        id: grid

        readonly property int columns: Math.floor(root.width / root.cell)

        model: columns + Math.floor(root.height / root.cell)

        Rectangle {
            required property int index
            readonly property bool upright: index < grid.columns

            x: upright ? (index + 1) * root.cell : 0
            y: upright ? 0 : (index - grid.columns + 1) * root.cell
            width: upright ? 1 : root.width
            height: upright ? root.height : 1
            color: Theme.alpha(Theme.text, 0.035)
        }
    }

    Repeater {
        model: tiles.rows

        Rectangle {
            id: tile

            required property string key
            readonly property var monitor: tiles.byKey[key] ?? null
            readonly property var box: monitor ? Layout.rect(monitor) : ({ x: 0, y: 0, w: 0, h: 0 })
            readonly property bool isSelected: key === root.selected

            x: root.view.x + box.x * root.view.zoom
            y: root.view.y + box.y * root.view.zoom
            width: box.w * root.view.zoom
            height: box.h * root.view.zoom
            z: isSelected ? 1 : 0
            radius: Theme.px(8)
            color: Theme.crust
            border.width: isSelected ? Theme.px(2) : 1
            border.color: isSelected ? Theme.accent : Theme.alpha(Theme.text, 0.2)

            // Tiles glide to where the layout puts them, which makes snapping feel magnetic.
            Behavior on x {
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }
            Behavior on y {
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }
            Behavior on width {
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }
            Behavior on height {
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }

            // The desktop behind the label: the monitor shows the wallpaper, after all.
            RoundImage {
                anchors.fill: parent
                anchors.margins: tile.border.width
                radius: tile.radius - tile.border.width
                color: "transparent"
                source: Fmt.file(Daemon.wallpaper.current?.image ?? "")
                opacity: tile.isSelected ? 0.5 : 0.25

                Behavior on opacity {
                    NumberAnimation { duration: Theme.normal }
                }
            }

            Column {
                anchors.centerIn: parent
                width: parent.width - Theme.px(10)
                spacing: Theme.px(2)

                // Its foot points to the bottom edge of the panel, to show which way the monitor is turned.
                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: tile.height > Theme.px(84)
                    text: Icons.monitor
                    size: 26
                    color: tile.isSelected ? Theme.accent : Theme.text
                    rotation: ((tile.monitor?.transform ?? 0) % 4) * 90

                    Behavior on rotation {
                        RotationAnimation { duration: Theme.slow; easing.type: Easing.OutBack; direction: RotationAnimation.Shortest }
                    }
                }

                Txt {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: tile.key
                    size: 13
                    bold: true
                }

                // Only on a tile with room for it: a small one keeps just its name.
                Txt {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    visible: tile.height > Theme.px(48) && tile.width > Theme.px(124)
                    text: tile.monitor ? tile.monitor.width + "×" + tile.monitor.height + " · " + Math.round(tile.monitor.refreshRate) + " Hz" : ""
                    size: 10
                    color: Theme.subtext
                }
            }

            MouseArea {
                // Where the button went down, in canvas pixels.
                property point press

                anchors.fill: parent
                cursorShape: root.monitors.length < 2 ? Qt.PointingHandCursor : pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                onPressed: mouse => {
                    press = mapToItem(root, mouse.x, mouse.y);
                    root.picked(tile.key);
                }
                onPositionChanged: mouse => {
                    if (root.monitors.length < 2)
                        return;
                    const at = mapToItem(root, mouse.x, mouse.y);
                    // A click must not start a drag: wait until the pointer has really moved.
                    if (!root.held && Math.hypot(at.x - press.x, at.y - press.y) > Theme.px(6))
                        root.grab(tile.key, press);
                    if (root.held)
                        root.drag(at);
                }
                onReleased: root.release()
                onCanceled: root.release()
            }
        }
    }
}
