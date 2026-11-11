import QtQuick
import qs.core
import qs.widgets
import "binds.js" as Binds

// The keybind cheat-sheet: every bind Hyprland has right now, asked for when
// the page opens, grouped by what it is for and searchable by key or action.
FocusScope {
    id: view

    // What `hypr.binds` answered; null until it has.
    property var binds: null
    property string error: ""
    // The group shown, "" for all of them.
    property string group: ""
    // The reply may arrive after the guide was closed; closures check this first.
    readonly property var life: ({ over: false })

    readonly property var sheet: Binds.sheet(binds, Daemon.setting("keybinds", []))
    readonly property var found: Binds.matching(sheet.entries, search.text)
    readonly property var counts: Binds.counts(found)
    readonly property var rows: Binds.rows(group === "" ? found : found.filter(entry => entry.group === group), sheet.groups)
    readonly property bool loading: binds === null && error === ""
    readonly property string nothing: error !== "" ? "Could not read the keybinds: " + error
        : sheet.entries.length === 0 ? "Hyprland has no keybinds"
        : search.text.trim() !== "" ? "No bind matches “" + search.text.trim() + "”" : "Nothing in this group"

    function load() {
        const life = view.life;
        view.error = "";
        Daemon.call("hypr.binds", {}, (binds, error) => {
            if (life.over)
                return;
            view.error = error ?? "";
            if (!error)
                view.binds = binds;
        });
    }

    focus: true
    Component.onCompleted: load()
    Component.onDestruction: life.over = true

    PageTitle {
        anchors.left: parent.left
        anchors.right: search.left
        title: "Keybinds"
        subtitle: view.binds === null ? "Asking Hyprland…" : view.binds.length + " binds, live from Hyprland"
    }

    IconBtn {
        anchors.right: search.left
        anchors.rightMargin: Theme.px(8)
        anchors.verticalCenter: search.verticalCenter
        icon: Icons.refresh
        iconColor: Theme.subtext
        onClicked: view.load()
    }

    Field {
        id: search

        anchors.right: parent.right
        width: Theme.px(320)
        focus: true
        icon: Icons.search
        placeholder: "Search keys or actions"
    }

    Flow {
        id: chips

        anchors.top: search.bottom
        anchors.topMargin: Theme.px(22)
        width: parent.width
        spacing: Theme.px(8)

        FilterChip {
            text: "All"
            count: view.found.length
            active: view.group === ""
            onClicked: view.group = ""
        }

        Repeater {
            model: view.sheet.groups

            FilterChip {
                required property var modelData

                // A group without matches hides, unless it is the one selected.
                visible: count > 0 || active
                text: modelData.title
                count: view.counts[modelData.id] ?? 0
                active: view.group === modelData.id
                onClicked: view.group = active ? "" : modelData.id
            }
        }
    }

    List {
        id: list

        anchors.top: chips.bottom
        anchors.bottom: parent.bottom
        anchors.topMargin: Theme.px(8)
        // Wider than the rows, so that the scroll indicator runs beside them.
        width: parent.width + Theme.px(12)
        spacing: 0
        model: view.rows

        delegate: Loader {
            required property var modelData

            width: view.width
            sourceComponent: modelData.header !== undefined ? heading : bind
        }
    }

    Component {
        id: bind

        BindRow {
            entry: parent.modelData
        }
    }

    Component {
        id: heading

        Item {
            readonly property var group: parent.modelData

            implicitHeight: Theme.px(44)

            Txt {
                id: name

                anchors.bottom: parent.bottom
                anchors.bottomMargin: Theme.px(8)
                x: Theme.px(10)
                text: parent.group.header
                size: 12
                bold: true
                color: Theme.accent
            }

            Rectangle {
                anchors.left: name.right
                anchors.right: parent.right
                anchors.leftMargin: Theme.px(12)
                anchors.rightMargin: Theme.px(12)
                anchors.verticalCenter: name.verticalCenter
                height: 1
                color: Theme.border
            }
        }
    }

    Spinner {
        anchors.centerIn: parent
        visible: view.loading
    }

    Column {
        anchors.centerIn: parent
        visible: !view.loading && view.rows.length === 0
        spacing: Theme.px(12)

        Txt {
            anchors.horizontalCenter: parent.horizontalCenter
            text: view.nothing
            color: view.error !== "" ? Theme.error : Theme.dim
        }

        Btn {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: view.error !== ""
            text: "Try again"
            icon: Icons.refresh
            onClicked: view.load()
        }
    }
}
