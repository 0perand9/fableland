import QtQuick
import qs.core
import qs.widgets

// One setting inside a Section: its name and explanation on the left and its
// control on the right — or underneath at full width when `stacked`. The typed
// rows (ToggleRow, NumberRow, TextRow, ...) add the control; a page can also
// put any single item in here.
//
// Rows take the keyboard focus (the sidebar moves it with the arrow keys, from
// one `focusStop` to the next): Enter or Space is `activated`, Left and Right
// are `nudged`.
//
// A setting the system configuration fixes shows its value and says so; its
// control does nothing.
Item {
    id: root

    property string label: ""
    property string hint: ""
    // Dotted path of the setting this row edits. The search matches it too, so
    // "lock" finds everything under lock.*.
    property string path: ""
    // Extra words the search should find this row by.
    property string keywords: ""
    readonly property bool fixed: path !== "" && Daemon.fixed(path)
    property bool stacked: false
    // False takes the row away for a reason other than the search (say, it
    // belongs to a provider that is not selected).
    property bool available: true
    // Whether the row wants to be on show. Sections and pages count these;
    // `visible` cannot be used for that because it also turns false whenever an
    // ancestor hides.
    readonly property bool shown: available && (!searchable || (parent !== null && parent.wholePage === true) || Search.matches(label, hint, path, keywords))
    // Rows of a form that belongs to something else (an entry of a list) are not searched one by one.
    property bool searchable: true
    // Makes the whole row a click target (toggles).
    property bool clickable: false
    // Whether the sidebar's arrow keys stop at this row; false for one with nothing to do.
    property bool focusStop: true
    default property Item control

    signal clicked
    signal activated
    signal nudged(int by)

    readonly property real inset: Theme.px(14)
    readonly property real innerWidth: width - 2 * inset
    property real padding: Theme.px(11)
    readonly property bool hasText: label !== "" || hint !== "" || fixed

    width: parent ? parent.width : 0
    implicitHeight: stacked ? slot.y + slot.height + padding : Math.max(labels.height, slot.height, Theme.px(26)) + 2 * padding
    visible: shown

    onActivated: {
        if (clickable)
            clicked();
    }
    // Only keys pressed on the row itself: a text field inside passes on Enter,
    // and the arrows at either end of its text, which are not meant for the row.
    Keys.enabled: activeFocus && !fixed
    Keys.onReturnPressed: activated()
    Keys.onEnterPressed: activated()
    Keys.onSpacePressed: activated()
    Keys.onLeftPressed: nudged(-1)
    Keys.onRightPressed: nudged(1)

    onControlChanged: {
        if (control)
            control.parent = slot;
    }

    // A stacked control spans the row.
    Binding {
        target: root.control
        property: "width"
        value: root.innerWidth
        when: root.stacked && root.control !== null
    }

    // Hairline towards the row above (the Section says which row is the first).
    Rectangle {
        visible: root.parent && root.parent.firstShown !== root
        x: root.inset
        width: root.innerWidth
        height: 1
        color: Theme.border
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: Theme.px(4)
        radius: Theme.radiusSmall
        color: root.activeFocus ? Theme.alpha(Theme.accent, 0.1) : Theme.alpha(Theme.text, press.pressed ? 0.08 : press.containsMouse ? 0.04 : 0)
        border.width: 1
        border.color: Theme.alpha(Theme.accent, root.activeFocus ? 0.55 : 0)

        Behavior on color {
            ColorAnimation { duration: Theme.fast }
        }
    }

    MouseArea {
        id: press

        anchors.fill: parent
        enabled: root.clickable && !root.fixed
        hoverEnabled: enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    Column {
        id: labels

        x: root.inset
        y: root.stacked ? root.padding : Math.round((root.height - height) / 2)
        width: root.stacked ? root.innerWidth : root.innerWidth - slot.width - Theme.px(12)
        visible: root.hasText
        spacing: Theme.px(2)

        Txt {
            visible: root.label !== ""
            width: parent.width
            text: root.label
            size: 13
            wrapMode: Text.WordWrap
            elide: Text.ElideNone
        }

        Txt {
            visible: root.hint !== ""
            width: parent.width
            text: root.hint
            size: 11
            color: Theme.dim
            wrapMode: Text.WordWrap
            elide: Text.ElideNone
        }

        FixedNote {
            visible: root.fixed
        }
    }

    Item {
        id: slot

        x: root.stacked ? root.inset : root.width - root.inset - width
        y: !root.stacked ? Math.round((root.height - height) / 2) : root.hasText ? labels.y + labels.height + Theme.px(8) : root.padding
        width: root.stacked ? root.innerWidth : root.control ? root.control.width : 0
        height: root.control ? root.control.height : 0
        enabled: !root.fixed
        opacity: enabled ? 1 : 0.5
    }
}
