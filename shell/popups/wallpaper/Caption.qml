import QtQuick
import qs.core
import qs.widgets

// The line under the carousel: what the focused card is, and where it stands in the row.
Row {
    id: root

    // The focused library item or search result, or null.
    property var entry: null
    property bool searching: false
    // The focused wallpaper is the one on screen.
    property bool showing: false
    // The focused search result is being saved into the library.
    property bool downloading: false
    // Why it could not be saved.
    property string problem: ""
    // Its place among the cards, as "3 / 120".
    property string place: ""

    height: Theme.px(22)
    spacing: Theme.px(12)

    Txt {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, Theme.px(560))
        // A library item goes by its file name, a search result by its title.
        text: root.entry?.name ?? root.entry?.title ?? ""
        size: 14
        bold: true
    }

    Txt {
        anchors.verticalCenter: parent.verticalCenter
        visible: text !== ""
        size: 12
        color: root.problem !== "" ? Theme.red : root.showing ? Theme.accent : Theme.subtext
        text: {
            if (!root.entry)
                return "";
            if (root.problem !== "")
                return root.problem;
            if (root.searching)
                return root.downloading ? "Downloading…" : root.entry.width + " × " + root.entry.height;
            return root.showing ? "On screen now" : root.entry.video ? "Video" : "";
        }
    }

    Txt {
        anchors.verticalCenter: parent.verticalCenter
        visible: root.entry !== null
        text: root.place
        size: 12
        color: Theme.dim
    }
}
