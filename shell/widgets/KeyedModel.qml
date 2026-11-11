import QtQuick

// Turns a JS array from a daemon topic into a model whose delegates survive
// updates. Assigning an array to a view's `model` rebuilds every delegate on
// each change — which kills hover states, running animations and sliders being
// dragged. This keeps one row per `key` and only inserts, moves and removes.
//
//   KeyedModel { id: sinks; source: Daemon.audio.sinks; key: "id" }
//   List {
//       model: sinks.rows
//       delegate: Item {
//           required property string key
//           readonly property var sink: sinks.byKey[key] ?? ({})
//       }
//   }
QtObject {
    id: root

    property var source: []
    property string key: "id"
    // key → the latest object with that key.
    property var byKey: ({})
    readonly property ListModel rows: ListModel {}
    readonly property int count: rows.count
    // The keys of `rows`, in order (reading them back from the model is slow).
    property var order: []

    function sync() {
        const map = {}, keys = [];
        for (const item of source ?? []) {
            const k = String(item[key]);
            if (k in map)
                continue;
            map[k] = item;
            keys.push(k);
        }

        // When most rows move (a re-sorted or replaced list), starting over is
        // far cheaper than moving them one by one — and nothing would have
        // stayed in place anyway.
        let displaced = Math.abs(keys.length - order.length);
        for (let i = 0; i < Math.min(keys.length, order.length); i++)
            if (keys[i] !== order[i])
                displaced++;
        if (displaced > Math.max(8, keys.length / 2)) {
            rows.clear();
            for (const k of keys)
                rows.append({ key: k });
            order = keys;
            byKey = map;
            return;
        }

        const now = order.slice();
        for (let i = now.length - 1; i >= 0; i--) {
            if (!(now[i] in map)) {
                rows.remove(i);
                now.splice(i, 1);
            }
        }
        for (let i = 0; i < keys.length; i++) {
            if (now[i] === keys[i])
                continue;
            const at = now.indexOf(keys[i], i + 1);
            if (at >= 0) {
                rows.move(at, i, 1);
                now.splice(at, 1);
            } else {
                rows.insert(i, { key: keys[i] });
            }
            now.splice(i, 0, keys[i]);
        }
        order = now;
        byKey = map;
    }

    onSourceChanged: sync()
    onKeyChanged: sync()
    Component.onCompleted: sync()
}
