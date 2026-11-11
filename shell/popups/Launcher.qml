import QtQuick
import qs.core
import qs.widgets
import qs.popups.launcher

// The application launcher. Typing ranks the installed applications; a query
// can also be arithmetic ("=" forces it), a shell command (">") or a web
// search ("?"). When nothing is installed by that name, the last two are offered.
PopupPage {
    id: page

    readonly property string query: search.text.trim()
    // ">" asks for a shell command, "?" for a web search, "=" for a calculation.
    readonly property string prefix: query !== "" && ">?=".includes(query.charAt(0)) ? query.charAt(0) : ""
    // The query without its prefix.
    readonly property string subject: prefix === "" ? query : query.slice(1).trim()
    // The value of the query when it is arithmetic (or declared to be, with "="), else "".
    readonly property string sum: prefix === "" || prefix === "=" ? calculator.evaluate(subject, prefix === "=") : ""
    readonly property string mode: prefix === ">" ? "run" : prefix === "?" ? "web" : prefix === "=" || sum !== "" ? "calc" : "apps"
    readonly property var matches: mode === "apps" ? ranker.rank(subject) : []
    // What the list shows: applications as published, or action rows (see actionRow).
    readonly property var results: {
        if (mode !== "apps")
            return [actionRow(mode, mode === "calc" ? sum : subject)];
        // Nothing installed by that name: offer what else could be meant.
        return matches.length === 0 && subject !== "" ? [actionRow("web", subject), actionRow("run", subject)] : matches;
    }
    readonly property string searchUrl: Daemon.setting("launcher.searchUrl", "")

    readonly property int rowHeight: Theme.px(60)
    readonly property int rowStep: rowHeight + list.spacing
    readonly property int rowsPerPage: Math.max(1, Math.floor(list.height / rowStep))

    // What a query can be besides the name of an application.
    readonly property var actions: ({
            calc: { icon: Icons.calculator, label: "Calculator", verb: "Copy", effect: "Copy the result", prompt: "Type something to work out, like =2*(3+4)" },
            run: { icon: Icons.terminal, label: "Shell command", verb: "Run", effect: "Run as a shell command", prompt: "Type a shell command after >" },
            web: { icon: Icons.web, label: "Web search", verb: "Search", effect: "Search the web", prompt: "Type what to look for after ?" }
        })

    // A row for one of the actions. `value` is what Enter acts on — the
    // result, the command, the search — and "" while there is nothing yet,
    // when the row only says what to type.
    function actionRow(action, value) {
        const kind = actions[action];
        const title = value === "" ? kind.label : action === "calc" ? "= " + value : value;
        return { action: action, value: value, icon: kind.icon, verb: kind.verb, title: title, subtitle: value === "" ? kind.prompt : kind.effect };
    }

    function activate(entry) {
        if (!entry)
            return;
        if (entry.action === undefined)
            Daemon.send("apps.launch", { id: entry.id });
        else if (entry.value === "")
            return;
        else if (entry.action === "calc")
            Daemon.send("clipboard.copyText", { text: entry.value });
        else if (entry.action === "run")
            Daemon.send("apps.run", { command: entry.value });
        else
            Daemon.send("misc.open", { target: searchUrl.replace("{query}", encodeURIComponent(entry.value)) });
        close();
    }

    function select(index) {
        if (list.count > 0)
            list.currentIndex = Math.max(0, Math.min(list.count - 1, index));
    }

    // One row up or down, around the ends.
    function step(delta) {
        if (list.count > 0)
            list.currentIndex = (list.currentIndex + delta + list.count) % list.count;
    }

    function navigate(where) {
        switch (where) {
        case "up": case "previous": step(-1); break;
        case "down": case "next": step(1); break;
        case "pageUp": select(list.currentIndex - rowsPerPage); break;
        case "pageDown": select(list.currentIndex + rowsPerPage); break;
        case "first": select(0); break;
        case "last": select(list.count - 1); break;
        }
    }

    implicitWidth: Theme.px(800)
    implicitHeight: Theme.px(634)

    // Cheap unless something was installed or removed since the last time.
    Component.onCompleted: Daemon.send("apps.refresh")

    Calculator {
        id: calculator
    }

    AppRanker {
        id: ranker

        apps: Daemon.apps
    }

    Backdrop {
        anchors.fill: parent
        colors: [Theme.accent, Theme.blue]
    }

    SearchBar {
        id: search

        width: parent.width
        focus: true
        placeholder: "Search applications"
        icon: page.mode === "apps" ? Icons.search : page.actions[page.mode].icon
        onAccepted: page.activate(page.results[list.currentIndex])
        onNavigate: where => page.navigate(where)

        Txt {
            anchors.verticalCenter: parent.verticalCenter
            text: page.mode !== "apps" ? page.actions[page.mode].label
                : page.subject === "" ? Daemon.apps.length + " apps" : page.matches.length + " of " + Daemon.apps.length
            size: 11
            color: Theme.dim
        }
    }

    Rectangle {
        id: divider

        anchors.top: search.bottom
        width: parent.width
        height: 1
        color: Theme.border
    }

    Txt {
        anchors.centerIn: list
        visible: list.count === 0
        text: "No applications found"
        color: Theme.dim
    }

    List {
        id: list

        anchors.top: divider.bottom
        anchors.bottom: footer.top
        anchors.margins: Theme.px(10)
        x: Theme.px(10)
        width: parent.width - 2 * x
        // A plain array, not a KeyedModel: a keystroke reorders most of the
        // list, and rebuilding the few visible rows takes a fraction of the
        // time it takes to move 140 model rows into their new order. The view
        // starts again from the first (best) row whenever it gets a new one.
        model: page.results
        // Rows are that cheap, so none are prepared off-screen either.
        cacheBuffer: 0
        onCurrentIndexChanged: {
            if (currentIndex >= 0)
                positionViewAtIndex(currentIndex, ListView.Contain);
        }

        delegate: ResultRow {
            required property var modelData
            required property int index

            width: list.width
            height: page.rowHeight
            entry: modelData
            selected: index === list.currentIndex
            onClicked: page.activate(entry)
        }

        // The selection, scrolling with the rows and underneath them.
        Stretch {
            parent: list.contentItem
            vertical: true
            width: list.width
            radius: Theme.radius
            visible: list.currentIndex >= 0
            targetStart: list.currentIndex * page.rowStep
            targetEnd: targetStart + page.rowHeight
        }
    }

    Item {
        id: footer

        anchors.bottom: parent.bottom
        width: parent.width
        height: Theme.px(40)

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.border
        }

        KeyHints {
            x: Theme.px(20)
            anchors.verticalCenter: parent.verticalCenter
            model: {
                const verb = list.currentItem ? list.currentItem.verb : "";
                return [{ key: "↑↓", label: "Navigate" }].concat(verb !== "" ? { key: "Enter", label: verb } : []);
            }
        }

        KeyHints {
            anchors.right: parent.right
            anchors.rightMargin: Theme.px(20)
            anchors.verticalCenter: parent.verticalCenter
            model: [{ key: "=", label: "Calculate" }, { key: ">", label: "Run a command" }, { key: "?", label: "Search the web" }]
        }
    }
}
