pragma Singleton
import QtQuick
import Quickshell

// What the plugins add to the shell, from their plugin.json (Daemon.plugins).
// Their QML is in plugins/<name>/; a plugin that is switched off adds nothing.
//
//   popup      Ui opens it like any other, by the plugin's name
//   bar        drawn in the bar's "bar" slot
//   settings   a page of its own in Settings
//   slots      places other parts of the shell leave open (widgets/Slot.qml)
Singleton {
    id: root

    readonly property var list: Daemon.plugins.filter(plugin => Daemon.has(plugin.name))
    readonly property var popups: list.filter(plugin => plugin.shell.popup).map(plugin => plugin.name)
    readonly property var settingsPages: list.filter(plugin => plugin.shell.settings).map(plugin => ({ key: plugin.name, title: plugin.title || plugin.name, short: plugin.short, icon: plugin.icon, file: url(plugin.name, plugin.shell.settings) }))

    function find(name) {
        return list.find(plugin => plugin.name === name) ?? null;
    }

    // A file of a plugin's shell/ folder.
    function url(name, file) {
        return Qt.resolvedUrl("../plugins/" + name + "/" + file);
    }

    function popupFile(name) {
        const plugin = find(name);
        return plugin && plugin.shell.popup ? url(name, plugin.shell.popup) : "";
    }

    // What the plugins put in a slot: [{ plugin, url }], in the order of the build.
    function slot(name) {
        if (name === "bar")
            return list.filter(plugin => plugin.shell.bar).map(plugin => ({ plugin: plugin.name, url: url(plugin.name, plugin.shell.bar) }));
        return list.filter(plugin => plugin.shell.slots && plugin.shell.slots[name]).map(plugin => ({ plugin: plugin.name, url: url(plugin.name, plugin.shell.slots[name]) }));
    }
}
