import QtQuick
import qs.core

SettingsPage {
    Section {
        TextRow {
            path: "updates.flakeDir"
            label: "Flake folder"
            hint: "The flake whose inputs are watched; found automatically when empty"
            keywords: "directory path nix"
            directory: true
            placeholder: Daemon.updates.flakeDir ?? ""
        }

        TextRow {
            path: "updates.command"
            label: "Update command"
            hint: "Runs in the terminal; a suitable one is chosen when empty"
            keywords: "upgrade nix rebuild"
            placeholder: Daemon.updates.command ?? ""
            icon: Icons.terminal
        }

        NumberRow {
            path: "updates.intervalHours"
            label: "Check every"
            keywords: "interval hours frequency"
            from: 1
            to: 168
            unit: "h"
        }

        ActionRow {
            label: Daemon.updates.checking ? "Checking…" : "Check now"
            hint: !Daemon.updates.supported ? "No flake found" : Daemon.updates.count > 0 ? Daemon.updates.count + " inputs are behind" : "Everything is up to date"
            keywords: "updates refresh"
            button: "Check"
            icon: Icons.refresh
            onTriggered: Daemon.send("updates.check")
        }
    }
}
