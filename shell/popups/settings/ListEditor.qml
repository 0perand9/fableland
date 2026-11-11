import QtQuick
import qs.core
import qs.widgets

// Edits a setting that is a list. Every entry gets a `delegate` in a list that
// grows with its content up to `maxHeight` and scrolls by itself beyond that,
// so a long list stays virtualised. Every change writes the list whole.
// A list the system configuration fixes is shown, and nothing in it responds.
//
// A delegate declares `required property string key` — the entry's index —
// and reads `editor.entries[Number(key)]`. Items put inside the ListEditor
// land at the right end of its title line (an "Add" button).
Column {
    id: root

    property string title: ""
    property string path: ""
    property Component delegate
    property real maxHeight: Theme.px(400)
    property string emptyText: ""
    // Whether an entry matches the search: entry => bool.
    property var matches: entry => true
    // Index of the entry that is open for editing, -1 for none.
    property int expanded: -1
    default property alias actions: actionSlot.data

    readonly property var entries: {
        const stored = Daemon.setting(path, []);
        return Array.isArray(stored) ? stored : [];
    }
    // The search names the page this list is on: all entries stay.
    readonly property bool wholePage: parent !== null && parent.titleMatches === true
    readonly property bool shown: !Search.active || wholePage || rows.count > 0
    readonly property bool fixed: Daemon.fixed(path)

    function write(list) {
        Daemon.setSetting(path, list);
    }

    function append(entry) {
        write(entries.concat([entry]));
    }

    function replace(index, entry) {
        const list = entries.slice();
        list[index] = entry;
        write(list);
    }

    // Change some fields of an entry that is an object.
    function update(index, changes) {
        replace(index, Object.assign({}, entries[index], changes));
    }

    function remove(index) {
        if (expanded === index)
            expanded = -1;
        else if (expanded > index)
            expanded--;
        write(entries.filter((entry, i) => i !== index));
    }

    function move(index, by) {
        const to = index + by;
        if (to < 0 || to >= entries.length)
            return;
        const list = entries.slice();
        list.splice(to, 0, list.splice(index, 1)[0]);
        if (expanded === index)
            expanded = to;
        else if (expanded === to)
            expanded = index;
        write(list);
    }

    width: parent ? parent.width : 0
    spacing: Theme.px(8)
    visible: shown

    // Entries are told apart by their index, so a delegate (and its focus) survives edits.
    KeyedModel {
        id: rows

        source: root.entries.map((entry, index) => ({ id: index, entry: entry })).filter(row => root.wholePage || root.matches(row.entry))
        // An entry that was just added to be filled in (see `expanded`) is at the end: go there.
        onCountChanged: {
            if (root.expanded === root.entries.length - 1)
                list.positionViewAtEnd();
        }
    }

    Item {
        width: parent.width
        height: Math.max(caption.height, actionSlot.height)

        Txt {
            id: caption

            x: Theme.px(6)
            anchors.verticalCenter: parent.verticalCenter
            text: root.entries.length > 0 ? root.title + " · " + root.entries.length : root.title
            size: 10.5
            bold: true
            color: Theme.dim
            font.capitalization: Font.AllUppercase
            font.letterSpacing: Theme.px(1)
        }

        Row {
            id: actionSlot

            visible: !root.fixed
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.px(6)
        }

        FixedNote {
            visible: root.fixed
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Txt {
        visible: root.entries.length === 0 && root.emptyText !== ""
        x: Theme.px(6)
        width: parent.width - 2 * x
        text: root.emptyText
        size: 12
        color: Theme.dim
        wrapMode: Text.WordWrap
        elide: Text.ElideNone
    }

    List {
        id: list

        width: parent.width
        height: Math.min(contentHeight, root.maxHeight)
        visible: count > 0
        enabled: !root.fixed
        opacity: enabled ? 1 : 0.6
        spacing: Theme.px(8)
        // The sidebar moves the keyboard focus through entries and the rows of their forms alike.
        keyNavigationEnabled: false
        model: rows.rows
        delegate: root.delegate
    }
}
