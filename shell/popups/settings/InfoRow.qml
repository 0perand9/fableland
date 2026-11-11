import QtQuick
import qs.core
import qs.widgets

// A fact to read, not a setting: a name with its value.
SettingRow {
    id: root

    property string value: ""

    focusStop: false

    Txt {
        width: Math.min(implicitWidth, root.innerWidth - Theme.px(70))
        horizontalAlignment: Text.AlignRight
        text: root.value
        size: 12
        color: Theme.subtext
    }
}
