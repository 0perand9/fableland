import QtQuick
import qs.core
import qs.widgets

// Draws a Selection — everything around it dimmed, a frame with corner
// handles, the size — and lets the pointer change it:
//   drag on open ground                     a new selection
//   drag an edge or a corner                resize
//   drag the size label, or Shift + drag    move
//   right click                             cancel
Item {
    id: root

    required property Selection selection
    property color hue: Theme.accent
    // Real pixels per unit of this item: the size label counts in pixels.
    property real pixelRatio: 1
    // Shown while nothing is selected.
    property string hint: ""
    // Something else (the toolbar) sits above the selection: the size label goes inside.
    property bool labelInside: false
    // Changes not made by the pointer glide. Off until the first selection is in place.
    property bool gliding: false

    readonly property bool shown: selection.width > 0 && selection.height > 0
    // How close to an edge a press still grabs it.
    readonly property real reach: Theme.px(12)

    signal cancelled

    component Glide: Behavior {
        enabled: root.gliding && !root.selection.dragging

        NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic }
    }

    component Shade: Rectangle {
        color: Theme.alpha(Theme.crust, 0.55)
    }

    component Handle: Rectangle {
        required property real centerX
        required property real centerY

        x: centerX - width / 2
        y: centerY - height / 2
        width: Theme.px(12)
        height: width
        radius: width / 2
        color: Theme.text
        border.width: Theme.px(2)
        border.color: root.hue
        visible: root.selection.exists
    }

    function gripAt(px, py, modifiers) {
        const onLabel = label.visible && px >= label.x && px <= label.x + label.width && py >= label.y && py <= label.y + label.height;
        if (selection.exists && (onLabel || (modifiers & Qt.ShiftModifier)))
            return "move";
        return selection.gripAt(px, py, reach);
    }

    function cursorFor(grip) {
        switch (grip) {
        case "move": return selection.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor;
        case "n": case "s": return Qt.SizeVerCursor;
        case "e": case "w": return Qt.SizeHorCursor;
        case "nw": case "se": return Qt.SizeFDiagCursor;
        case "ne": case "sw": return Qt.SizeBDiagCursor;
        default: return Qt.CrossCursor;
        }
    }

    // The selection as drawn.
    Item {
        id: frame

        x: root.selection.x
        y: root.selection.y
        width: root.selection.width
        height: root.selection.height

        Glide on x {}
        Glide on y {}
        Glide on width {}
        Glide on height {}
    }

    // Four shades around the frame; with nothing selected the lower one covers everything.
    Item {
        anchors.fill: parent

        NumberAnimation on opacity {
            from: 0
            to: 1
            duration: Theme.normal
        }

        Shade {
            width: parent.width
            height: frame.y
        }

        Shade {
            y: frame.y + frame.height
            width: parent.width
            height: parent.height - y
        }

        Shade {
            y: frame.y
            width: frame.x
            height: frame.height
        }

        Shade {
            x: frame.x + frame.width
            y: frame.y
            width: parent.width - x
            height: frame.height
        }
    }

    // Drawn around the selection rather than over its outermost pixels,
    // except where the screen ends.
    Rectangle {
        x: Math.max(0, frame.x - border.width)
        y: Math.max(0, frame.y - border.width)
        width: Math.min(root.width, frame.x + frame.width + border.width) - x
        height: Math.min(root.height, frame.y + frame.height + border.width) - y
        visible: root.shown
        color: "transparent"
        border.width: Theme.px(2)
        border.color: root.hue
    }

    Handle { centerX: frame.x; centerY: frame.y }
    Handle { centerX: frame.x + frame.width; centerY: frame.y }
    Handle { centerX: frame.x; centerY: frame.y + frame.height }
    Handle { centerX: frame.x + frame.width; centerY: frame.y + frame.height }

    Rectangle {
        id: label

        readonly property real gap: Theme.px(10)
        readonly property bool inside: root.labelInside || frame.y - height - gap < 0

        x: Math.max(0, Math.min(root.width - width, frame.x + (inside ? gap : 0)))
        y: inside ? frame.y + gap : frame.y - height - gap
        width: readout.implicitWidth + Theme.px(20)
        height: Theme.px(28)
        radius: Theme.radiusSmall
        visible: root.shown
        color: Theme.alpha(Theme.base, 0.9)
        border.width: 1
        border.color: Theme.border

        Row {
            id: readout

            anchors.centerIn: parent
            spacing: Theme.px(6)

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                text: Icons.drag
                size: 14
                color: Theme.subtext
            }

            Txt {
                anchors.verticalCenter: parent.verticalCenter
                text: Math.round(frame.width * root.pixelRatio) + " × " + Math.round(frame.height * root.pixelRatio)
                size: 12
                bold: true
            }
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: hintText.implicitWidth + Theme.px(40)
        height: Theme.px(48)
        radius: height / 2
        visible: opacity > 0
        opacity: root.shown || root.hint === "" ? 0 : 1
        color: Theme.alpha(Theme.base, 0.9)
        border.width: 1
        border.color: Theme.border

        Behavior on opacity {
            NumberAnimation { duration: Theme.fast }
        }

        Txt {
            id: hintText

            anchors.centerIn: parent
            text: root.hint
            size: 14
        }
    }

    MouseArea {
        id: pointer

        // The grip under the resting pointer.
        property string hovering: "new"

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: root.cursorFor(root.selection.dragging ? root.selection.grip : hovering)
        onPressed: mouse => {
            if (mouse.button === Qt.RightButton)
                root.cancelled();
            else
                root.selection.press(mouse.x, mouse.y, root.gripAt(mouse.x, mouse.y, mouse.modifiers));
        }
        onPositionChanged: mouse => {
            if (root.selection.dragging)
                root.selection.drag(mouse.x, mouse.y);
            else
                hovering = root.gripAt(mouse.x, mouse.y, mouse.modifiers);
        }
        onReleased: mouse => {
            root.selection.release();
            hovering = root.gripAt(mouse.x, mouse.y, mouse.modifiers);
        }
    }
}
