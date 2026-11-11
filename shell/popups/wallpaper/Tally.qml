import QtQuick
import qs.core
import qs.widgets

// How much there is to browse: the size of the library, or of the search so far.
Row {
    id: root

    // Count the online results rather than the library.
    property bool searching: false
    // More is on its way: thumbnails are being made, or the search is running.
    property bool working: false

    readonly property var library: Daemon.wallpaper
    readonly property var online: Daemon.wallsearch

    spacing: Theme.px(10)

    Spinner {
        anchors.verticalCenter: parent.verticalCenter
        visible: root.working
        implicitWidth: Theme.px(16)
        implicitHeight: Theme.px(16)
    }

    Txt {
        anchors.verticalCenter: parent.verticalCenter
        size: 12
        color: Theme.dim
        text: {
            if (root.searching) {
                const found = root.online.results.length;
                return root.working ? found + " found so far" : found > 0 ? found + " results for “" + root.online.query + "”" : "";
            }
            const have = root.library.items.length;
            return root.working ? "Making thumbnails… " + have + " ready" : have + " wallpapers in " + Daemon.setting("wallpaper.dir", root.library.dir);
        }
    }
}
