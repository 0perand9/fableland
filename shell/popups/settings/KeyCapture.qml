import QtQuick
import qs.core
import qs.widgets

// Shows a key combination and records a new one: click the box, then press the
// combination. The pencil switches to typing it instead — for what cannot be
// pressed here (mouse buttons, media keys, combinations Hyprland already acts on).
// Combinations are in Hyprland's notation: "SUPER + SHIFT + D".
Item {
    id: root

    property string keys: ""
    property bool recording: false
    property bool typing: false
    // The modifiers held so far while recording.
    property var held: []

    signal captured(string keys)

    readonly property var modifierKeys: ({
            [Qt.Key_Meta]: Qt.MetaModifier, [Qt.Key_Super_L]: Qt.MetaModifier, [Qt.Key_Super_R]: Qt.MetaModifier,
            [Qt.Key_Control]: Qt.ControlModifier, [Qt.Key_Alt]: Qt.AltModifier, [Qt.Key_Shift]: Qt.ShiftModifier,
            [Qt.Key_AltGr]: Qt.NoModifier, [Qt.Key_CapsLock]: Qt.NoModifier, [Qt.Key_NumLock]: Qt.NoModifier
        })
    // xkb names of the keys that are neither letters, digits nor function keys.
    // Symbols typed with Shift go by the key they sit on (US layout), since Shift is part of the combination.
    readonly property var keyNames: ({
            [Qt.Key_Return]: "Return", [Qt.Key_Enter]: "KP_Enter", [Qt.Key_Space]: "space", [Qt.Key_Tab]: "Tab", [Qt.Key_Backtab]: "Tab",
            [Qt.Key_Backspace]: "BackSpace", [Qt.Key_Delete]: "Delete", [Qt.Key_Insert]: "Insert", [Qt.Key_Home]: "Home", [Qt.Key_End]: "End",
            [Qt.Key_PageUp]: "Prior", [Qt.Key_PageDown]: "Next", [Qt.Key_Left]: "left", [Qt.Key_Right]: "right", [Qt.Key_Up]: "up", [Qt.Key_Down]: "down",
            [Qt.Key_Print]: "Print", [Qt.Key_Pause]: "Pause", [Qt.Key_Menu]: "Menu", [Qt.Key_Escape]: "Escape",
            [Qt.Key_Minus]: "minus", [Qt.Key_Underscore]: "minus", [Qt.Key_Equal]: "equal", [Qt.Key_Plus]: "equal",
            [Qt.Key_BracketLeft]: "bracketleft", [Qt.Key_BraceLeft]: "bracketleft", [Qt.Key_BracketRight]: "bracketright", [Qt.Key_BraceRight]: "bracketright",
            [Qt.Key_Backslash]: "backslash", [Qt.Key_Bar]: "backslash", [Qt.Key_Semicolon]: "semicolon", [Qt.Key_Colon]: "semicolon",
            [Qt.Key_Apostrophe]: "apostrophe", [Qt.Key_QuoteDbl]: "apostrophe", [Qt.Key_QuoteLeft]: "grave", [Qt.Key_AsciiTilde]: "grave",
            [Qt.Key_Comma]: "comma", [Qt.Key_Less]: "comma", [Qt.Key_Period]: "period", [Qt.Key_Greater]: "period", [Qt.Key_Slash]: "slash", [Qt.Key_Question]: "slash",
            [Qt.Key_Exclam]: "1", [Qt.Key_At]: "2", [Qt.Key_NumberSign]: "3", [Qt.Key_Dollar]: "4", [Qt.Key_Percent]: "5",
            [Qt.Key_AsciiCircum]: "6", [Qt.Key_Ampersand]: "7", [Qt.Key_Asterisk]: "8", [Qt.Key_ParenLeft]: "9", [Qt.Key_ParenRight]: "0",
            [Qt.Key_VolumeUp]: "XF86AudioRaiseVolume", [Qt.Key_VolumeDown]: "XF86AudioLowerVolume", [Qt.Key_VolumeMute]: "XF86AudioMute",
            [Qt.Key_MediaPlay]: "XF86AudioPlay", [Qt.Key_MediaTogglePlayPause]: "XF86AudioPlay", [Qt.Key_MediaNext]: "XF86AudioNext", [Qt.Key_MediaPrevious]: "XF86AudioPrev",
            [Qt.Key_MonBrightnessUp]: "XF86MonBrightnessUp", [Qt.Key_MonBrightnessDown]: "XF86MonBrightnessDown"
        })

    function modifierNames(modifiers) {
        const names = [];
        if (modifiers & Qt.MetaModifier)
            names.push("SUPER");
        if (modifiers & Qt.ControlModifier)
            names.push("CTRL");
        if (modifiers & Qt.AltModifier)
            names.push("ALT");
        if (modifiers & Qt.ShiftModifier)
            names.push("SHIFT");
        return names;
    }

    // The name Hyprland knows a pressed key by; "" for a key that is only a modifier.
    function keyName(event) {
        const key = event.key;
        if (key in modifierKeys)
            return "";
        if ((key >= Qt.Key_A && key <= Qt.Key_Z) || (key >= Qt.Key_0 && key <= Qt.Key_9))
            return String.fromCharCode(key);
        if (key >= Qt.Key_F1 && key <= Qt.Key_F24)
            return "F" + (key - Qt.Key_F1 + 1);
        if (key in keyNames)
            return keyNames[key];
        // Other layouts and unusual keys go by their key code, which Hyprland accepts as well.
        return event.nativeScanCode > 0 ? "code:" + event.nativeScanCode : "";
    }

    // A typed combination in the notation used everywhere else: "super+shift+d" → "SUPER + SHIFT + d".
    function tidy(typed) {
        const modifiers = ["SUPER", "CTRL", "CONTROL", "ALT", "SHIFT"];
        return typed.split("+").map(part => part.trim()).filter(part => part !== "").map(part => modifiers.indexOf(part.toUpperCase()) >= 0 ? part.toUpperCase() : part).join(" + ");
    }

    function record() {
        typing = false;
        recording = true;
        box.forceActiveFocus();
    }

    function stopRecording() {
        recording = false;
        held = [];
    }

    implicitWidth: Theme.px(220)
    implicitHeight: Theme.px(34)

    Rectangle {
        id: box

        anchors.left: parent.left
        anchors.right: pencil.left
        anchors.rightMargin: Theme.px(4)
        height: parent.height
        visible: !root.typing
        radius: Theme.radiusSmall
        color: Theme.alpha(root.recording ? Theme.accent : Theme.surface0, root.recording ? 0.12 : 0.6)
        border.width: 1
        border.color: root.recording ? Theme.alpha(Theme.accent, 0.7) : Theme.border

        onActiveFocusChanged: {
            if (!activeFocus)
                root.stopRecording();
        }
        Keys.onPressed: event => {
            if (!root.recording)
                return;
            event.accepted = true;
            const name = root.keyName(event);
            if (name === "") {
                root.held = root.modifierNames(event.modifiers | root.modifierKeys[event.key]);
            } else if (name === "Escape" && event.modifiers === Qt.NoModifier) {
                // Escape on its own leaves the recording; with modifiers it is a combination like any other.
                root.stopRecording();
            } else {
                const combination = root.modifierNames(event.modifiers).concat([name]).join(" + ");
                root.stopRecording();
                root.captured(combination);
            }
        }
        Keys.onReleased: event => {
            if (!root.recording)
                return;
            event.accepted = true;
            root.held = root.modifierNames(event.modifiers & ~(root.modifierKeys[event.key] ?? 0));
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.recording ? root.stopRecording() : root.record()
        }

        Row {
            x: Theme.px(10)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.px(8)

            KeyCaps {
                anchors.verticalCenter: parent.verticalCenter
                keys: root.recording ? root.held.join(" + ") : root.keys
            }

            Txt {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.recording || root.keys === ""
                text: root.recording ? "Press the keys…" : "Click to record"
                size: 12
                color: root.recording ? Theme.accent : Theme.dim

                SequentialAnimation on opacity {
                    running: root.recording && root.visible
                    loops: Animation.Infinite
                    alwaysRunToEnd: true

                    NumberAnimation { to: 0.35; duration: 600; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: 600; easing.type: Easing.InOutSine }
                }
            }
        }
    }

    CommitField {
        id: field

        anchors.left: parent.left
        anchors.right: pencil.left
        anchors.rightMargin: Theme.px(4)
        height: parent.height
        visible: root.typing
        value: root.keys
        placeholder: "SUPER + SHIFT + D"
        onCommitted: text => root.captured(root.tidy(text))
        onAccepted: root.typing = false
        onActiveFocusChanged: {
            if (!activeFocus)
                root.typing = false;
        }
    }

    IconBtn {
        id: pencil

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        icon: root.typing ? Icons.check : Icons.edit
        size: 30
        iconColor: Theme.subtext
        onClicked: {
            root.stopRecording();
            root.typing = !root.typing;
            if (root.typing)
                field.forceActiveFocus();
        }
    }
}
