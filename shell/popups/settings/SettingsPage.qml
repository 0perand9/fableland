import QtQuick
import qs.core

// The root of a page of the sidebar: Sections (and ListEditors) in a column.
// The sidebar shows one page at a time, or — while searching — every page with
// only its matching rows.
Column {
    // Both are set by the sidebar. A search for the page's title shows all of the page.
    property string title: ""
    // Height of the sidebar's scrolling area, for lists that should fill the
    // page and scroll by themselves rather than grow without limit.
    property real viewHeight: 0
    readonly property bool titleMatches: Search.active && Search.matches(title)
    readonly property bool shown: {
        for (const part of children)
            if (part.shown)
                return true;
        return false;
    }

    spacing: Theme.px(16)
}
