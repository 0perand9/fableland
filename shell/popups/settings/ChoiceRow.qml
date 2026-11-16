import QtQuick
import qs.core
import qs.widgets

// A setting with a fixed set of values. Two or three of them make a segmented
// control beside the label; more become chips underneath it, all visible at once.
SettingRow {
    id: root

    // [{ value, label }], or plain strings that are value and label at once.
    property var options: []
    // With what plugins add to this setting (their plugin.json `choices`).
    readonly property var choices: options.concat(Plugins.choices(path))
    property bool segmented: choices.length <= 3
    // Width of one segment (design units); widen it for long labels.
    property real segmentWidth: 76
    readonly property var current: Daemon.setting(path, "")
    readonly property int currentIndex: choices.findIndex(option => valueOf(option) === current)

    function valueOf(option) {
        return typeof option === "string" ? option : option.value;
    }

    function labelOf(option) {
        return typeof option === "string" ? Fmt.capitalize(option) : option.label;
    }

    function choose(index) {
        if (index !== currentIndex)
            Daemon.setSetting(path, valueOf(choices[index]));
    }

    stacked: !segmented
    onNudged: by => choose(Math.max(0, Math.min(choices.length - 1, currentIndex + by)))
    onActivated: choose((currentIndex + 1) % choices.length)
    keywords: choices.map(option => labelOf(option)).join(" ")

    Loader {
        sourceComponent: root.segmented ? segments : chips

        Component {
            id: segments

            Tabs {
                implicitWidth: Theme.px(root.segmentWidth) * root.choices.length
                implicitHeight: Theme.px(32)
                size: 12
                model: root.choices.map(option => root.labelOf(option))
                current: root.currentIndex
                onSelected: index => root.choose(index)
            }
        }

        Component {
            id: chips

            Chips {
                labels: root.choices.map(option => root.labelOf(option))
                current: root.currentIndex
                onPicked: index => root.choose(index)
            }
        }
    }
}
