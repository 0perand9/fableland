import QtQuick
import qs.core
import qs.widgets

// A titled group of SettingRows on one card. It disappears while a search
// leaves none of its rows on show, and while the feature it is about is off.
Column {
    id: root

    property string title: ""
    // The feature (Daemon.has) these settings belong to, if they belong to one.
    property string feature: ""
    default property alias rows: body.data
    readonly property bool shown: Daemon.has(feature) && body.firstShown !== null
    // The search names the page this section is on: nothing on it is filtered out.
    readonly property bool wholePage: parent !== null && parent.titleMatches === true

    width: parent ? parent.width : 0
    spacing: Theme.px(6)
    visible: shown

    Txt {
        visible: root.title !== ""
        x: Theme.px(6)
        text: root.title
        size: 10.5
        bold: true
        color: Theme.dim
        font.capitalization: Font.AllUppercase
        font.letterSpacing: Theme.px(1)
    }

    Card {
        width: parent.width
        implicitHeight: body.height

        Column {
            id: body

            // Rows look these up: whether the search spares them all, and which of
            // them is the first on show (it draws no hairline above itself).
            readonly property bool wholePage: root.wholePage
            readonly property Item firstShown: {
                for (const row of children)
                    if (row.shown)
                        return row;
                return null;
            }

            width: parent.width
        }
    }
}
