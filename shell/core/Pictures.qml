pragma Singleton
import QtQuick
import Quickshell

// Pictures from the web, by URL. The daemon downloads each one once into its
// cache (converting formats Qt may not be able to read) and hands back a local
// path. Use the RemoteImage widget; or call fetch(url) and bind to paths[url].
Singleton {
    id: root

    // url → local file, filled in as downloads finish.
    property var paths: ({})

    function fetch(url) {
        if (!url || url in internal.asked)
            return;
        internal.asked[url] = true;
        Daemon.call("misc.image", { url: url }, (file, error) => {
            if (file) {
                root.paths[url] = file;
                root.pathsChanged();
            } else {
                // Not remembered as asked, so showing it again retries.
                delete internal.asked[url];
            }
        });
    }

    QtObject {
        id: internal

        property var asked: ({})
    }
}
