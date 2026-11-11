import QtQuick
import qs.core
import qs.widgets

// Directory suggestions under a path field while it is being typed in.
// Tab (or a click) takes a suggestion, the arrow keys choose among them.
Column {
    id: root

    required property CommitField field
    property var paths: []
    property int selected: 0

    function refresh() {
        const prefix = field.text;
        if (prefix === "") {
            paths = [];
            return;
        }
        Daemon.call("misc.suggestDirs", { prefix: prefix, limit: 5 }, found => {
            // Answers can arrive after more typing (or after the row is gone): only the latest counts.
            if (root && field.text === prefix) {
                paths = found ?? [];
                selected = 0;
            }
        });
    }

    function take(path) {
        field.text = path;
        field.edited = true;
        refresh();
    }

    // Both report whether there was a suggestion to act on.
    function complete() {
        if (!visible)
            return false;
        take(paths[selected]);
        return true;
    }

    function step(by) {
        if (!visible)
            return false;
        selected = (selected + by + paths.length) % paths.length;
        return true;
    }

    visible: field.activeFocus && paths.length > 0
    topPadding: Theme.px(4)

    Connections {
        target: root.field.input

        function onTextEdited() {
            root.refresh();
        }
    }

    Connections {
        target: root.field

        function onActiveFocusChanged() {
            if (!root.field.activeFocus)
                root.paths = [];
        }

        // Enter ends the completing, whether or not the path changed.
        function onAccepted() {
            root.paths = [];
        }
    }

    Repeater {
        model: root.paths

        Clickable {
            id: suggestion

            required property string modelData
            required property int index

            width: root.width
            height: Theme.px(28)
            fill: index === root.selected ? Theme.alpha(Theme.accent, 0.14) : "transparent"
            onClicked: root.take(modelData)

            Icon {
                id: glyph

                x: Theme.px(10)
                anchors.verticalCenter: parent.verticalCenter
                text: Icons.folderOpen
                size: 14
                color: suggestion.index === root.selected ? Theme.accent : Theme.dim
            }

            Txt {
                anchors.left: glyph.right
                anchors.right: parent.right
                anchors.leftMargin: Theme.px(8)
                anchors.rightMargin: Theme.px(10)
                anchors.verticalCenter: parent.verticalCenter
                text: suggestion.modelData
                size: 12
                color: Theme.subtext
                elide: Text.ElideLeft
            }
        }
    }
}
