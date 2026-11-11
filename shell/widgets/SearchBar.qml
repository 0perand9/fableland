import QtQuick
import qs.core

// The search line heading the launcher and the clipboard: a mode icon, the
// query, and room on the right for extras. It keeps the keyboard focus, so it
// also turns keys into navigation for the results below it.
FocusScope {
    id: root

    property alias text: input.text
    property string placeholder: ""
    property string icon: Icons.search
    property color accentColor: Theme.accent
    // Results laid out as a grid: Left/Right move the selection, not the text cursor.
    property bool grid: false
    default property alias extras: trailing.data

    // Enter was pressed.
    signal accepted
    // "up" "down" "left" "right" "pageUp" "pageDown" "first" "last", "next" (Tab) or "previous" (Shift+Tab).
    signal navigate(string where)
    // Every key before the bar acts on it; set `event.accepted` to claim it.
    signal keyPressed(var event)

    function navigationFor(event) {
        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
        switch (event.key) {
        case Qt.Key_Up: return "up";
        case Qt.Key_Down: return "down";
        case Qt.Key_Left: return grid ? "left" : "";
        case Qt.Key_Right: return grid ? "right" : "";
        case Qt.Key_PageUp: return "pageUp";
        case Qt.Key_PageDown: return "pageDown";
        case Qt.Key_Home: return "first";
        case Qt.Key_End: return "last";
        case Qt.Key_Tab: return "next";
        case Qt.Key_Backtab: return "previous";
        case Qt.Key_P: case Qt.Key_K: return ctrl ? "up" : "";
        case Qt.Key_N: case Qt.Key_J: return ctrl ? "down" : "";
        case Qt.Key_H: return ctrl && grid ? "left" : "";
        case Qt.Key_L: return ctrl && grid ? "right" : "";
        default: return "";
        }
    }

    implicitHeight: Theme.px(64)

    Icon {
        id: glyph

        anchors.left: parent.left
        anchors.leftMargin: Theme.px(22)
        anchors.verticalCenter: parent.verticalCenter
        text: root.icon
        size: 22
        color: root.accentColor
        // A change of mode pops.
        onTextChanged: pop.restart()

        NumberAnimation {
            id: pop

            target: glyph
            property: "scale"
            from: 0.5
            to: 1
            duration: Theme.normal
            easing.type: Easing.OutBack
        }
    }

    TextInput {
        id: input

        anchors.left: glyph.right
        anchors.right: trailing.left
        anchors.leftMargin: Theme.px(14)
        anchors.rightMargin: Theme.px(14)
        anchors.verticalCenter: parent.verticalCenter
        focus: true
        clip: true
        color: Theme.text
        font.family: Theme.font
        font.pixelSize: Theme.px(16)
        selectByMouse: true
        selectionColor: Theme.alpha(root.accentColor, 0.4)
        selectedTextColor: Theme.text

        // Handled before the input itself, which would otherwise keep Home, End and Ctrl+K.
        Keys.onPressed: event => {
            root.keyPressed(event);
            if (event.accepted)
                return;
            const where = root.navigationFor(event);
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                root.accepted();
            else if (where !== "")
                root.navigate(where);
            else
                return;
            event.accepted = true;
        }
    }

    Txt {
        anchors.fill: input
        visible: input.text === "" && input.preeditText === ""
        text: root.placeholder
        size: 16
        color: Theme.dim
    }

    Row {
        id: trailing

        anchors.right: parent.right
        anchors.rightMargin: Theme.px(20)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.px(10)
    }
}
