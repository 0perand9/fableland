import QtQuick
import qs.core
import qs.widgets

// Beside a title's Open button in Movies: whether Sonarr (a series) or Radarr
// (a film) has it, and a button that requests it. Not there for a service that
// is not set up.
Btn {
    id: root

    property var context: null

    readonly property var title: context?.title ?? ({})
    readonly property string service: title.type === "series" ? "sonarr" : "radarr"
    readonly property string serviceName: service === "sonarr" ? "Sonarr" : "Radarr"
    readonly property string titleId: title.id ?? ""
    readonly property bool configured: Daemon.topic("arr", ({}))[service] === true
    // arr.lookup's answer for the title on show, or why there is none.
    property var known: null
    property string error: ""
    property bool busy: false

    function params() {
        return { id: title.id, title: title.title ?? "", type: title.type ?? "movie" };
    }

    // `loud`: say why it failed (when asked again after a failure).
    function lookup(loud) {
        known = null;
        error = "";
        if (!configured || titleId === "")
            return;
        busy = true;
        const id = titleId;
        Daemon.call("arr.lookup", params(), (result, failure) => {
            // Another title may be on show by now.
            if (id !== root.titleId)
                return;
            busy = false;
            known = result ?? null;
            error = failure ?? "";
            if (failure && loud)
                Daemon.toast("error", root.serviceName, failure);
        });
    }

    function request() {
        busy = true;
        const id = titleId;
        Daemon.call("arr.request", params(), (result, failure) => {
            if (id !== root.titleId)
                return;
            busy = false;
            if (failure) {
                Daemon.toast("error", root.serviceName, failure);
                return;
            }
            known = result;
        });
    }

    visible: configured && titleId !== ""
    size: 14
    accentColor: context?.hue ?? Theme.accent
    interactive: !busy && known?.found !== false
    icon: error !== "" ? Icons.error : known?.inLibrary ? Icons.checkCircle : Icons.download
    text: {
        if (busy)
            return known ? "Requesting…" : "Asking " + serviceName + "…";
        if (error !== "")
            return serviceName + " failed · retry";
        if (!known)
            return serviceName;
        if (!known.found)
            return "Not on " + serviceName;
        if (!known.inLibrary)
            return "Request on " + serviceName;
        const have = Number(known.have ?? 0);
        const progress = have >= 100 ? (service === "sonarr" ? "complete" : "downloaded") : service === "sonarr" && have > 0 ? Math.round(have) + "%" : "wanted";
        return "In " + serviceName + " · " + progress;
    }
    onClicked: {
        if (error !== "")
            lookup(true);
        else if (known && known.inLibrary && known.link)
            Daemon.send("misc.open", { target: known.link });
        else if (known && !known.inLibrary)
            request();
    }
    onTitleIdChanged: lookup(false)
    onConfiguredChanged: lookup(false)
    Component.onCompleted: lookup(false)
}
