import QtQuick
import qs.core
import qs.widgets

// What sits above the trending grid: the searches the daemon remembers and the
// titles that were opened last.
Column {
    id: root

    property color hue: Theme.accent

    signal searchPicked(string query)

    spacing: Theme.px(20)

    Column {
        visible: Catalog.searches.length > 0
        width: parent.width
        spacing: Theme.px(10)

        Heading {
            text: "Recent searches"
        }

        Flow {
            width: parent.width
            spacing: Theme.px(8)

            Repeater {
                model: Catalog.searches

                Chip {
                    required property string modelData

                    text: modelData
                    size: 13
                    removable: true
                    onClicked: root.searchPicked(modelData)
                    onRemoved: Catalog.forget(modelData)
                }
            }
        }
    }

    Column {
        visible: Catalog.watched.length > 0
        width: parent.width
        spacing: Theme.px(4)

        Heading {
            text: "Recently opened"
        }

        ListView {
            // The cells bring their own inset; this lines the posters up with the heading.
            x: -Theme.px(8)
            width: parent.width + Theme.px(16)
            height: Theme.px(216)
            orientation: ListView.Horizontal
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            model: Catalog.watched

            delegate: TitleCell {
                required property var modelData

                width: Theme.px(136)
                height: ListView.view.height
                title: modelData
                compact: true
                hue: root.hue
                onPicked: Catalog.show(modelData)
            }
        }
    }
}
