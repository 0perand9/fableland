import QtQuick
import qs.core

// The clipboard history as the daemon serves it: a page at a time, filtered by
// `query` on the daemon's side. `entries` grows when the view asks for more.
QtObject {
    id: root

    property string query: ""
    // Rows of { key, kind: "text"|"image", text, image } — `key` is the entry's id.
    readonly property ListModel entries: ListModel {}
    // How many entries match `query`, loaded or not.
    property int total: 0
    property bool loading: false
    // Why the history cannot be read, if it cannot.
    property string error: ""
    readonly property bool complete: nextOffset >= total
    readonly property int pageSize: 36

    // Where the next page starts in the daemon's list.
    property int nextOffset: 0
    // Counts the reloads: answers to anything but the latest one are dropped.
    property int generation: 0
    // The keys in `entries` — the history may grow between two pages, which repeats entries.
    property var known: ({})

    // The first page for a new query has replaced whatever was listed.
    signal replaced

    function reload() {
        generation++;
        fetch(0);
    }

    function loadMore() {
        if (!loading && !complete)
            fetch(nextOffset);
    }

    function fetch(offset) {
        const asked = generation;
        loading = true;
        Daemon.call("clipboard.list", { offset: offset, limit: pageSize, query: query }, (result, error) => {
            if (asked !== generation)
                return;
            loading = false;
            root.error = error ?? "";
            if (error)
                return;
            if (offset === 0) {
                entries.clear();
                known = {};
                nextOffset = 0;
            }
            for (const item of result.items) {
                if (item.id in known)
                    continue;
                known[item.id] = true;
                entries.append({ key: item.id, kind: item.kind, text: item.text ?? "", image: item.image ?? "" });
            }
            total = result.total;
            // Relative, because entries may have been removed while the page was on its way.
            nextOffset += pageSize;
            if (offset === 0)
                replaced();
        });
    }

    function remove(key) {
        attempt("clipboard.delete", { id: key }, () => {
            for (let i = 0; i < entries.count; i++) {
                if (entries.get(i).key !== key)
                    continue;
                entries.remove(i);
                total--;
                nextOffset--;
                break;
            }
            delete known[key];
        });
    }

    function wipe() {
        attempt("clipboard.wipe", {}, reload);
    }

    // The entries change only once the daemon has done it. It announces
    // failures only of calls that expect no answer, so these are passed on the same way.
    function attempt(method, params, done) {
        Daemon.call(method, params, (result, error) => {
            if (error)
                Daemon.toast("error", method, error);
            else
                done();
        });
    }

    onQueryChanged: reload()
    Component.onCompleted: reload()
}
