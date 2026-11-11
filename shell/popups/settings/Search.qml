pragma Singleton
import QtQuick
import Quickshell

// What the settings sidebar is searching for. Rows ask `matches()` whether to
// stay on show, so a search filters every page in place instead of producing a
// second list of results.
Singleton {
    property string query: ""
    readonly property var words: query.toLowerCase().split(/\s+/).filter(word => word !== "")
    readonly property bool active: words.length > 0

    // True when every word of the query occurs somewhere in the given texts.
    function matches(...texts) {
        if (!active)
            return true;
        const haystack = texts.join(" ").toLowerCase();
        return words.every(word => haystack.includes(word));
    }
}
