import QtQuick
import qs.core
import qs.widgets

// What stands in the middle when a filter or a search has no cards to show.
Column {
    id: root

    // The filter that came up empty (see Wallpaper.qml).
    property string filter: "all"
    // Thumbnails are being made or the search is running: cards may yet come.
    property bool working: false

    readonly property bool searching: filter === "search"
    readonly property var library: Daemon.wallpaper
    readonly property var online: Daemon.wallsearch

    spacing: Theme.px(14)

    Spinner {
        anchors.horizontalCenter: parent.horizontalCenter
        visible: root.working
        implicitWidth: Theme.px(36)
        implicitHeight: Theme.px(36)
    }

    Icon {
        anchors.horizontalCenter: parent.horizontalCenter
        visible: !root.working
        text: root.searching ? Icons.web : Icons.images
        size: 44
        color: Theme.faint
    }

    Txt {
        anchors.horizontalCenter: parent.horizontalCenter
        size: 15
        color: Theme.dim
        text: {
            if (root.searching) {
                switch (root.online.state) {
                case "running": return "Searching…";
                case "error": return "The search did not work — is the network up?";
                case "done": return "Nothing in Full HD or larger for “" + root.online.query + "”";
                default: return "Type what you are looking for and press Enter";
                }
            }
            if (root.library.busy)
                return "Making thumbnails…";
            if (root.library.items.length === 0)
                return "No wallpapers in " + Daemon.setting("wallpaper.dir", root.library.dir);
            return "No " + root.filter + " wallpapers";
        }
    }
}
