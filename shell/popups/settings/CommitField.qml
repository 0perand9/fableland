import QtQuick
import qs.core
import qs.widgets

// A text field for a stored value. It shows `value` and reports an edit once —
// on Enter, when the field loses focus or when it goes away — never per
// keystroke. Escape takes an unfinished edit back.
Field {
    id: root

    // The stored value: shown whenever the user is not in the middle of an edit.
    property string value: ""
    // The user has typed since the last commit.
    property bool edited: false

    signal committed(string text)

    function commit() {
        if (!edited)
            return;
        edited = false;
        if (text === value)
            return;
        committed(text);
        // A refused write never comes back as a new value: return to the stored one then.
        refused.restart();
    }

    function revert() {
        edited = false;
        text = value;
        // A value longer than the field shows its beginning, not its end.
        if (!activeFocus)
            input.cursorPosition = 0;
    }

    implicitHeight: Theme.px(34)
    size: 12
    clearable: false

    onValueChanged: {
        if (!edited)
            revert();
    }
    Component.onCompleted: revert()
    Component.onDestruction: commit()
    onAccepted: commit()
    onActiveFocusChanged: {
        if (!activeFocus)
            commit();
    }
    // Only an edit in progress swallows Escape; otherwise it closes the sidebar.
    Keys.onEscapePressed: event => {
        event.accepted = edited;
        if (edited)
            revert();
    }

    Connections {
        target: root.input

        function onTextEdited() {
            root.edited = true;
        }
    }

    Timer {
        id: refused

        interval: 600
        onTriggered: {
            if (!root.edited)
                root.revert();
        }
    }
}
