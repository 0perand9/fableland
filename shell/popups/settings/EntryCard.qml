import QtQuick
import qs.core
import qs.widgets

// The base of a ListEditor's delegates: the card of one entry. It knows which
// entry it shows and, like a SettingRow, takes the keyboard focus — Enter is
// `activated`.
Card {
    id: root

    required property string key
    required property ListEditor editor
    readonly property int index: Number(key)
    // Undefined for a moment when the entry has just been removed.
    readonly property var entry: editor.entries[index]

    // The sidebar's arrow keys stop here (see SettingRow).
    readonly property bool focusStop: true

    signal activated

    // Scrolls the list as far as it takes to show this card.
    function reveal() {
        const view = ListView.view;
        if (view)
            view.contentY = Math.min(y, Math.max(view.contentY, y + height - view.height));
    }

    width: ListView.view ? ListView.view.width : 0
    border.color: activeFocus ? Theme.alpha(Theme.accent, 0.6) : Theme.border

    onActiveFocusChanged: {
        if (activeFocus)
            reveal();
    }
    // Only on the card itself; Enter in one of its fields is passed on to here as well.
    Keys.enabled: activeFocus
    Keys.onReturnPressed: activated()
    Keys.onEnterPressed: activated()
}
