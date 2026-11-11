import QtQuick
import qs.core
import qs.widgets

SettingsPage {
    id: page

    // Combinations Hyprland had bound by other means (its own configuration) when
    // the page opened, in the form made by `canonical`, each with what it does.
    property var taken: ({})

    // A combination in a form that can be compared: "shift+super+d".
    function canonical(modifiers, key) {
        return modifiers.map(name => name.toLowerCase() === "control" ? "ctrl" : name.toLowerCase()).sort().concat([key.toLowerCase()]).join("+");
    }

    function canonicalKeys(keys) {
        const parts = (keys ?? "").split("+").map(part => part.trim()).filter(part => part !== "");
        return canonical(parts.slice(0, -1), parts[parts.length - 1] ?? "");
    }

    // What else uses the combination of entry `index`; "" when nothing does.
    function conflictOf(keys, index) {
        const wanted = canonicalKeys(keys);
        if (binds.entries.some((other, i) => i !== index && other.enabled !== false && canonicalKeys(other.keys) === wanted))
            return "Another keybind in this list uses the same keys.";
        if (wanted in taken)
            return taken[wanted] !== "" ? "Hyprland's configuration already binds this to: " + taken[wanted] : "Hyprland's configuration already binds this.";
        return "";
    }

    Component.onCompleted: Daemon.call("hypr.binds", {}, found => {
        if (!page)
            return;
        // The entries of this list are applied to Hyprland too: those are not conflicts.
        const own = new Set(binds.entries.map(bind => canonicalKeys(bind.keys)));
        const map = {};
        for (const bind of found ?? []) {
            const combination = canonical(bind.mods, bind.key);
            if (bind.submap === "" && !own.has(combination))
                map[combination] = bind.action;
        }
        taken = map;
    })

    FableCommands {
        id: vocabulary
    }

    ListEditor {
        id: binds

        title: "Keybinds"
        path: "keybinds"
        maxHeight: page.viewHeight - Theme.px(110)
        emptyText: "None yet. Keybinds made here are applied on top of the ones in your Hyprland configuration, right away."
        matches: bind => Search.matches("keybinds shortcuts hotkeys", bind.keys, bind.command, bind.description)
        delegate: KeybindRow {
            editor: binds
            commands: vocabulary.all
            conflictOf: page.conflictOf
        }

        Btn {
            implicitHeight: Theme.px(30)
            text: "Add"
            icon: Icons.plus
            size: 12
            onClicked: {
                binds.expanded = binds.entries.length;
                binds.append({ keys: "", action: "exec", command: "", description: "", repeat: false, locked: false, enabled: true });
            }
        }
    }
}
