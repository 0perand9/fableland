import QtQuick
import qs.core

// A place plugins can fill: what each plugin names for this slot in its
// plugin.json is put here, side by side. Whatever the slot knows (the title on
// show, say) is handed to each as `context`, which the plugin's component
// declares as `property var context`.
//
//   Slot { name: "movies.details.actions"; context: ({ title: view.title }) }
//
// docs/PLUGINS.md lists the slots there are.
Row {
    id: slot

    required property string name
    property var context: null

    spacing: Theme.px(10)
    visible: repeater.count > 0

    Repeater {
        id: repeater

        model: Plugins.slot(slot.name)

        Loader {
            id: loader

            required property var modelData

            source: modelData.url
            anchors.verticalCenter: slot.verticalCenter
            onStatusChanged: {
                if (status === Loader.Error)
                    console.warn("fable: the plugin", modelData.plugin, "could not fill the slot", slot.name);
            }

            Binding {
                target: loader.item
                property: "context"
                value: slot.context
                when: loader.item !== null && "context" in loader.item
            }
        }
    }
}
