import QtQuick
import qs.core
import qs.widgets

// Finds a keyboard layout among everything xkb knows (about 600) by name or by
// code. A click picks one; so does Enter, for the match the arrow keys are on.
Column {
    id: root

    // Every layout: [{ id, name }].
    property var catalog: []
    // Ids of the layouts already in use; they are marked and cannot be picked again.
    property var chosen: []

    signal picked(string id)

    readonly property var found: {
        const words = field.text.toLowerCase().split(/\s+/).filter(word => word !== "");
        if (words.length === 0)
            return catalog;
        return catalog.filter(layout => {
            const haystack = (layout.name + " " + layout.id).toLowerCase();
            return words.every(word => haystack.includes(word));
        });
    }

    function pick(id) {
        if (chosen.indexOf(id) < 0)
            picked(id);
    }

    function focusField() {
        field.forceActiveFocus();
    }

    // Reports whether there was a match to move to (otherwise the key is not for the picker).
    function step(by) {
        const next = list.currentIndex + by;
        if (next < 0 || next >= found.length)
            return false;
        list.currentIndex = next;
        return true;
    }

    spacing: Theme.px(6)

    Field {
        id: field

        width: parent.width
        implicitHeight: Theme.px(34)
        size: 12
        icon: Icons.search
        placeholder: root.catalog.length > 0 ? "Search " + root.catalog.length + " layouts" : "Loading the layouts…"
        onAccepted: {
            if (list.currentIndex >= 0 && list.currentIndex < root.found.length)
                root.pick(root.found[list.currentIndex].id);
        }
        Keys.onDownPressed: event => event.accepted = root.step(1)
        Keys.onUpPressed: event => event.accepted = root.step(-1)
    }

    Txt {
        visible: root.catalog.length > 0 && root.found.length === 0
        x: Theme.px(6)
        text: "No layout matches"
        size: 12
        color: Theme.dim
    }

    List {
        id: list

        width: parent.width
        height: Math.min(contentHeight, Theme.px(204))
        visible: count > 0
        spacing: 0
        model: root.found
        // The match Enter would pick: marked only while the field is being typed in.
        highlight: Rectangle {
            visible: field.activeFocus
            radius: Theme.radiusSmall
            color: Theme.alpha(Theme.accent, 0.14)
        }

        delegate: Clickable {
            id: entry

            required property var modelData
            readonly property bool used: root.chosen.indexOf(modelData.id) >= 0

            width: list.width
            height: Theme.px(34)
            interactive: !used
            onClicked: root.pick(modelData.id)

            Txt {
                anchors.left: parent.left
                anchors.right: code.left
                anchors.leftMargin: Theme.px(10)
                anchors.rightMargin: Theme.px(8)
                anchors.verticalCenter: parent.verticalCenter
                text: entry.modelData.name
                size: 12
                color: entry.used ? Theme.dim : Theme.text
            }

            Txt {
                id: code

                anchors.right: mark.left
                anchors.rightMargin: Theme.px(8)
                anchors.verticalCenter: parent.verticalCenter
                text: entry.modelData.id
                size: 11
                color: Theme.dim
            }

            Icon {
                id: mark

                anchors.right: parent.right
                anchors.rightMargin: Theme.px(10)
                anchors.verticalCenter: parent.verticalCenter
                text: entry.used ? Icons.check : Icons.plus
                size: 14
                color: entry.used ? Theme.green : entry.hovered ? Theme.accent : Theme.dim
            }
        }
    }
}
