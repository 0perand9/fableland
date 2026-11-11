import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core
import qs.widgets

// Drawing on the screen: a see-through window over everything, with a toolbar
// at the bottom. With the pointer tool the drawing stays up while clicks go to
// the desktop underneath. Leaving (Esc) hides the drawing but keeps it, undo
// history included, until it is cleared.
PanelWindow {
    id: overlay

    required property var dock

    readonly property var tools: [
        { id: "pointer", icon: Icons.cursor, name: "Use the desktop", key: "V" },
        { id: "pen", icon: Icons.edit, name: "Pen", key: "P" },
        { id: "marker", icon: Icons.marker, name: "Highlighter", key: "H" },
        { id: "line", icon: Icons.vectorLine, name: "Line", key: "L" },
        { id: "arrow", icon: Icons.arrowTopRight, name: "Arrow", key: "A" },
        { id: "rect", icon: Icons.rectangle, name: "Rectangle", key: "R" },
        { id: "ellipse", icon: Icons.circleOutline, name: "Ellipse", key: "O" },
        { id: "eraser", icon: Icons.eraser, name: "Eraser", key: "E" }
    ]
    property string tool: "pen"
    property color ink: Theme.red
    // Stroke widths in design units, and how far each goes. The highlighter and
    // the eraser keep their own; every other tool draws as wide as the pen.
    property var widths: ({ pen: 4, marker: 22, eraser: 40 })
    readonly property var widthRanges: ({ pen: [1, 24], marker: [8, 56], eraser: [12, 120] })
    readonly property string widthOf: tool === "marker" || tool === "eraser" ? tool : "pen"
    // An opaque board behind the ink, for sketching rather than annotating.
    property bool board: false
    property bool inkOpen: false
    // A screenshot is being taken: the controls stay out of the picture.
    property bool saving: false
    property string notice: ""

    // With the pointer tool the desktop gets the clicks and the keyboard.
    readonly property bool passing: tool === "pointer"
    readonly property bool up: dock.drawing
    property real reveal: up ? 1 : 0

    // The board's dot grid, as a tile.
    readonly property string dots: {
        const pitch = Theme.px(24), c = Theme.text;
        const fill = "rgb(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + ")";
        return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='" + pitch + "' height='" + pitch + "'>"
            + "<circle cx='" + pitch / 2 + "' cy='" + pitch / 2 + "' r='" + 1.1 * Theme.scale + "' fill='" + fill + "' fill-opacity='0.16'/></svg>";
    }

    function pick(tool) {
        overlay.tool = tool;
    }

    function setInk(color) {
        ink = color;
        // Choosing a colour means wanting to draw with it.
        if (tool === "eraser" || tool === "pointer")
            tool = "pen";
    }

    function setWidth(value) {
        const [least, most] = widthRanges[widthOf];
        const next = Object.assign({}, widths);
        next[widthOf] = Math.max(least, Math.min(most, Math.round(value)));
        widths = next;
    }

    // The screen as it looks now — desktop, drawing and all — goes to the
    // screenshots folder and the clipboard. That is the capture feature's doing.
    function save() {
        if (!Daemon.has("capture"))
            return;
        inkOpen = false;
        saving = true;
        shutter.start();
    }

    function key(event) {
        const ctrl = event.modifiers & Qt.ControlModifier;
        const tool = ctrl ? undefined : tools.find(tool => tool.key === event.text.toUpperCase());
        if (event.key === Qt.Key_Escape) {
            if (inkOpen)
                inkOpen = false;
            else
                dock.drawing = false;
        } else if (ctrl && event.key === Qt.Key_Z) {
            if (event.modifiers & Qt.ShiftModifier)
                sketch.redo();
            else
                sketch.undo();
        } else if (ctrl && event.key === Qt.Key_Y) {
            sketch.redo();
        } else if (ctrl && event.key === Qt.Key_S) {
            save();
        } else if (event.key === Qt.Key_Delete) {
            sketch.clear();
        } else if (!ctrl && event.key === Qt.Key_B) {
            board = !board;
        } else if (tool) {
            pick(tool.id);
        } else {
            return;
        }
        event.accepted = true;
    }

    screen: dock.screen
    visible: up || reveal > 0
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "fableland-draw"
    WlrLayershell.keyboardFocus: up && !passing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: Region {
        item: overlay.passing ? controls : everything
    }

    onUpChanged: {
        inkOpen = false;
        saving = false;
        notice = "";
    }
    // The colour field may have held the keyboard.
    onInkOpenChanged: everything.forceActiveFocus()

    Behavior on reveal {
        NumberAnimation { duration: overlay.up ? Theme.normal : 160; easing.type: Easing.OutCubic }
    }

    // One moment for a frame without the controls to reach the screen.
    Timer {
        id: shutter

        interval: 150
        onTriggered: Daemon.call("capture.start", { mode: "full", monitor: overlay.screen.name }, (result, error) => {
            overlay.saving = false;
            overlay.notice = error ?? "";
        })
    }

    // Never leave the controls hidden if the reply does not come.
    Timer {
        interval: 5000
        running: overlay.saving
        onTriggered: overlay.saving = false
    }

    Timer {
        interval: 5000
        running: overlay.notice !== ""
        onTriggered: overlay.notice = ""
    }

    FocusScope {
        id: everything

        anchors.fill: parent
        focus: true
        opacity: overlay.reveal
        Keys.onPressed: event => overlay.key(event)

        Rectangle {
            anchors.fill: parent
            color: Theme.base
            opacity: overlay.board ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation { duration: Theme.normal }
            }

            Image {
                anchors.fill: parent
                fillMode: Image.Tile
                source: overlay.dots
            }
        }

        Sketch {
            id: sketch

            anchors.fill: parent
            enabled: !overlay.passing
            tool: overlay.tool
            ink: overlay.ink
            thickness: overlay.widths[overlay.widthOf] * Theme.scale
            onNudged: steps => {
                const [least, most] = overlay.widthRanges[overlay.widthOf];
                overlay.setWidth(overlay.widths[overlay.widthOf] + steps * Math.max(1, (most - least) / 16));
            }
        }

        Column {
            id: controls

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            // It rises into place as the overlay appears.
            anchors.bottomMargin: Theme.px(28) - (1 - overlay.reveal) * Theme.px(24)
            spacing: Theme.px(12)
            visible: !overlay.saving

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: overlay.notice !== ""
                width: Math.min(noticeRow.implicitWidth + Theme.px(28), toolbar.width)
                height: Theme.px(36)
                radius: height / 2
                color: Theme.alpha(Theme.base, 0.95)
                border.width: 1
                border.color: Theme.alpha(Theme.red, 0.5)

                Row {
                    id: noticeRow

                    anchors.centerIn: parent
                    width: Math.min(implicitWidth, parent.width - Theme.px(28))
                    spacing: Theme.px(8)

                    Icon {
                        id: noticeIcon

                        anchors.verticalCenter: parent.verticalCenter
                        text: Icons.error
                        size: 16
                        color: Theme.red
                    }

                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, toolbar.width - noticeIcon.width - Theme.px(36))
                        text: overlay.notice
                        size: 12
                    }
                }
            }

            InkPopover {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: overlay.inkOpen
                ink: overlay.ink
                thickness: overlay.widths[overlay.widthOf]
                thinnest: overlay.widthRanges[overlay.widthOf][0]
                thickest: overlay.widthRanges[overlay.widthOf][1]
                thicknessLabel: overlay.widthOf === "eraser" ? "Eraser" : overlay.widthOf === "marker" ? "Highlighter" : "Pen"
                onInkPicked: ink => overlay.setInk(ink)
                onThicknessPicked: thickness => overlay.setWidth(thickness)
            }

            DrawToolbar {
                id: toolbar

                tools: overlay.tools
                tool: overlay.tool
                ink: overlay.ink
                thickness: overlay.widths[overlay.widthOf]
                inkOpen: overlay.inkOpen
                board: overlay.board
                canUndo: sketch.canUndo
                canRedo: sketch.canRedo
                blank: sketch.blank
                onToolPicked: tool => overlay.pick(tool)
                onInkClicked: overlay.inkOpen = !overlay.inkOpen
                onUndo: sketch.undo()
                onRedo: sketch.redo()
                onClear: sketch.clear()
                onBoardToggled: overlay.board = !overlay.board
                onSave: overlay.save()
                onDone: overlay.dock.drawing = false
            }
        }
    }
}
