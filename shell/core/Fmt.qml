pragma Singleton
import QtQuick
import Quickshell

// Small formatting helpers shared by the views.
Singleton {
    // 75 → "1:15", 3675 → "1:01:15"
    function clock(seconds) {
        const s = Math.max(0, Math.floor(seconds));
        const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60), r = s % 60;
        const two = n => (n < 10 ? "0" : "") + n;
        return h > 0 ? h + ":" + two(m) + ":" + two(r) : m + ":" + two(r);
    }

    // 45 → "45s", 3675 → "1h 1m"
    function duration(seconds) {
        const s = Math.max(0, Math.round(seconds));
        if (s < 60)
            return s + "s";
        const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60);
        return h > 0 ? h + "h " + m + "m" : m + "m";
    }

    // How long ago a millisecond timestamp was: "now", "5m", "3h", "2d".
    function ago(ms) {
        const s = Math.max(0, (Date.now() - ms) / 1000);
        if (s < 60)
            return "now";
        if (s < 3600)
            return Math.floor(s / 60) + "m";
        if (s < 86400)
            return Math.floor(s / 3600) + "h";
        return Math.floor(s / 86400) + "d";
    }

    // 1536 → "1.5 KB"
    function bytes(n) {
        const units = ["B", "KB", "MB", "GB", "TB"];
        let i = 0;
        while (n >= 1024 && i < units.length - 1) {
            n /= 1024;
            i++;
        }
        return (i === 0 || n >= 100 ? Math.round(n) : n.toFixed(1)) + " " + units[i];
    }

    // A local path as a URL an Image can load ("" stays "").
    function file(path) {
        if (!path)
            return "";
        return path.startsWith("/") ? "file://" + path.split("/").map(encodeURIComponent).join("/") : path;
    }

    // An icon name or path (as found in desktop entries and notifications) as an
    // image source, or "" when the icon theme has no such icon.
    function icon(name) {
        if (!name)
            return "";
        if (name.startsWith("/") || name.startsWith("file://") || name.startsWith("image://"))
            return file(name);
        // Asking the icon theme costs a few milliseconds per name, every time —
        // far too slow for lists — so each name is looked up once.
        if (!iconSources.has(name))
            iconSources.set(name, Quickshell.iconPath(name, true));
        return iconSources.get(name);
    }

    readonly property var iconSources: new Map()

    function capitalize(s) {
        return s ? s.charAt(0).toUpperCase() + s.slice(1) : "";
    }
}
