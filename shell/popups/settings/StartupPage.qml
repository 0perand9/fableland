import QtQuick
import qs.core
import qs.widgets

SettingsPage {
    id: page

    Section {
        SettingRow {
            label: "Start with the session"
            hint: "Commands run once per Hyprland session, in the order below"
            keywords: "startup autostart login add"
            stacked: true
            // Nothing can be added to a list the system configuration fixes.
            available: !commands.fixed
            onActivated: draft.forceActiveFocus()

            Field {
                id: draft

                // A new command exists only once it is entered: an empty one is never stored.
                function add() {
                    const command = text.trim();
                    if (command === "")
                        return;
                    commands.append({ command: command, enabled: true });
                    text = "";
                }

                implicitHeight: Theme.px(34)
                size: 12
                icon: Icons.plus
                placeholder: "Add a command, like nm-applet"
                onAccepted: add()
            }
        }
    }

    ListEditor {
        id: commands

        title: "Commands"
        path: "startup"
        maxHeight: page.viewHeight - Theme.px(210)
        emptyText: "Nothing is started yet."
        matches: entry => Search.matches("startup autostart", entry.command)
        delegate: StartupRow {
            editor: commands
        }
    }
}
