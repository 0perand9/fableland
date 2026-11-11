import QtQuick
import Quickshell
import qs.core
import qs.widgets
import qs.popups.updates

// Updates of a flake-based NixOS: which flake inputs are behind their
// upstream, how old each lock is, and the command that brings the system up to
// date — held rather than clicked, because it rebuilds the system.
PopupPage {
    id: page

    readonly property var updates: Daemon.updates
    readonly property bool supported: updates.supported === true
    readonly property bool checking: updates.checking === true
    readonly property int behind: updates.count ?? 0
    // Behind first, then the inputs nothing is known about, then the current ones.
    readonly property var inputs: {
        const rank = { behind: 0, unknown: 1, current: 2 };
        return (updates.inputs ?? []).slice().sort((a, b) => (rank[a.status] ?? 1) - (rank[b.status] ?? 1) || a.name.localeCompare(b.name));
    }
    // Design units: an input's row with the gap below it, and everything around the list
    // (margins, the hero, the command) less the gap the last row does not have.
    readonly property int rowPitch: 62
    readonly property int surroundings: 262
    readonly property string headline: {
        if (checking)
            return "Checking for updates…";
        if (behind > 0)
            return behind === 1 ? "1 input is behind" : behind + " inputs are behind";
        return updates.lastCheck ? "Everything is up to date" : "Not checked yet";
    }

    // How long ago a moment (seconds since the epoch) was, in words. It reads the clock, so its users keep up with time.
    function ago(moment) {
        const seconds = clock.date.getTime() / 1000 - moment;
        for (const [unit, length] of [["year", 31557600], ["month", 2629800], ["day", 86400], ["hour", 3600], ["minute", 60]]) {
            const count = Math.floor(seconds / length);
            if (count >= 1)
                return count + " " + unit + (count === 1 ? "" : "s") + " ago";
        }
        return "just now";
    }

    function check() {
        Daemon.send("updates.check");
    }

    // The update runs in a terminal of its own, so the popup gets out of the way.
    function run() {
        Daemon.send("updates.run");
        close();
    }

    // Upstream in the browser — for an input that is behind, exactly the changes it is behind by.
    function showUpstream(input) {
        const changes = input.status === "behind" && input.rev && input.latest;
        Daemon.send("misc.open", { target: changes ? input.url + "/compare/" + input.rev + "..." + input.latest : input.url });
        close();
    }

    function scrollBy(distance) {
        const furthest = Math.max(0, list.contentHeight - list.height);
        list.contentY = list.originY + Math.max(0, Math.min(furthest, list.contentY - list.originY + distance));
    }

    implicitWidth: Theme.px(600)
    // As tall as the inputs need, within reason; without a flake there is only a message.
    implicitHeight: Theme.px(supported ? Math.max(420, Math.min(880, surroundings + rowPitch * inputs.length)) : 400)

    Keys.onPressed: event => {
        switch (event.key) {
        case Qt.Key_R:
        case Qt.Key_F5:
            if (!checking)
                check();
            break;
        case Qt.Key_Up: scrollBy(-Theme.px(rowPitch)); break;
        case Qt.Key_Down: scrollBy(Theme.px(rowPitch)); break;
        case Qt.Key_PageUp: scrollBy(-list.height); break;
        case Qt.Key_PageDown: scrollBy(list.height); break;
        default: return;
        }
        event.accepted = true;
    }

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    KeyedModel {
        id: entries

        source: page.inputs
        key: "name"
    }

    Backdrop {
        anchors.fill: parent
        colors: [Theme.green, Theme.accent, Theme.blue]
    }

    // ── no flake to watch ──
    Column {
        anchors.centerIn: parent
        width: parent.width - Theme.px(96)
        visible: !page.supported
        spacing: Theme.px(14)

        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Icons.nixos
            size: 64
            color: Theme.dim
        }

        Txt {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: "No flake to watch"
            size: 18
            bold: true
        }

        Txt {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: "No NixOS flake was found in /etc/nixos or your home folder. Name its folder in Settings (updates.flakeDir) and its inputs are watched for updates."
            size: 12
            color: Theme.subtext
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            topPadding: Theme.px(6)
            spacing: Theme.px(10)

            Btn {
                kind: "filled"
                icon: Icons.settings
                text: "Open Settings"
                onClicked: Ui.open("settings", "updates")
            }

            Btn {
                icon: Icons.refresh
                text: "Look again"
                onClicked: page.check()
            }
        }
    }

    Item {
        anchors.fill: parent
        anchors.margins: Theme.px(24)
        visible: page.supported

        // ── the state of things ──
        Row {
            id: hero

            width: parent.width
            spacing: Theme.px(20)

            Orb {
                id: orb

                // The fuller, the more up to date.
                level: page.inputs.length > 0 ? 1 - page.behind / page.inputs.length : 0
                text: page.behind > 0 ? page.behind : ""
                size: 34
                color: Theme.green
                pulsing: page.checking

                Icon {
                    anchors.centerIn: parent
                    visible: page.behind === 0 && page.inputs.length > 0
                    text: Icons.check
                    size: 48
                    color: Theme.accentText
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - orb.width - parent.spacing
                spacing: Theme.px(4)

                Txt {
                    width: parent.width
                    text: page.headline
                    size: 18
                    bold: true
                }

                Txt {
                    width: parent.width
                    visible: text !== ""
                    text: page.updates.lastCheck ? "Last checked " + page.ago(page.updates.lastCheck) : page.checking ? "" : "The first check runs shortly after the session starts"
                    size: 12
                    color: Theme.subtext
                }

                Row {
                    topPadding: Theme.px(8)
                    spacing: Theme.px(12)

                    Btn {
                        icon: Icons.refresh
                        text: "Check now"
                        interactive: !page.checking
                        onClicked: page.check()
                    }

                    Spinner {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: parent.topPadding / 2
                        visible: page.checking
                        color: Theme.green
                    }
                }
            }
        }

        // ── the inputs ──
        Txt {
            anchors.centerIn: list
            visible: entries.count === 0
            text: page.checking ? "Reading flake.lock…" : "flake.lock names no inputs"
            color: Theme.dim
        }

        List {
            id: list

            anchors.top: hero.bottom
            anchors.bottom: command.top
            anchors.topMargin: Theme.px(20)
            anchors.bottomMargin: Theme.px(16)
            width: parent.width
            model: entries.rows

            add: Transition {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.normal }
            }
            displaced: Transition {
                NumberAnimation { property: "y"; duration: Theme.normal; easing.type: Easing.OutCubic }
            }

            delegate: InputRow {
                required property string key

                width: list.width
                height: Theme.px(page.rowPitch) - list.spacing
                input: entries.byKey[key] ?? ({})
                age: input.lockedAt ? page.ago(input.lockedAt) : ""
                onClicked: page.showUpstream(input)
            }
        }

        // ── what will run ──
        Card {
            id: command

            anchors.left: parent.left
            anchors.right: runButton.left
            anchors.rightMargin: Theme.px(12)
            anchors.bottom: parent.bottom
            height: Theme.px(72)

            Icon {
                id: prompt

                x: Theme.px(14)
                anchors.verticalCenter: parent.verticalCenter
                text: Icons.terminal
                size: 20
                color: Theme.green
            }

            Column {
                anchors.left: prompt.right
                anchors.right: parent.right
                anchors.leftMargin: Theme.px(12)
                anchors.rightMargin: Theme.px(14)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.px(2)

                Txt {
                    width: parent.width
                    text: page.updates.flakeDir ?? ""
                    size: 10
                    color: Theme.dim
                    elide: Text.ElideMiddle
                }

                Txt {
                    width: parent.width
                    text: page.updates.command ?? ""
                    size: 12
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                }
            }
        }

        HoldBtn {
            id: runButton

            anchors.right: parent.right
            anchors.bottom: parent.bottom
            width: Theme.px(172)
            height: command.height
            vertical: true
            icon: Icons.update
            text: page.behind > 0 ? "Hold to update" : "Hold to run anyway"
            accentColor: Theme.green
            onTriggered: page.run()
        }
    }
}
