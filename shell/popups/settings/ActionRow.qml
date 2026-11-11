import QtQuick
import qs.core
import qs.widgets

// Something to do rather than to set: a description with a button.
// A `destructive` action has to be held down before it happens.
SettingRow {
    id: root

    property string button: ""
    property string icon: ""
    property bool destructive: false

    signal triggered

    keywords: button
    // From the keyboard too, a destructive action takes holding its button down with the pointer.
    onActivated: {
        if (!destructive)
            triggered();
    }

    Loader {
        sourceComponent: root.destructive ? holdButton : plainButton

        Component {
            id: plainButton

            Btn {
                implicitHeight: Theme.px(32)
                text: root.button
                icon: root.icon
                size: 12
                onClicked: root.triggered()
            }
        }

        Component {
            id: holdButton

            HoldBtn {
                implicitHeight: Theme.px(32)
                text: root.button
                icon: root.icon
                size: 12
                onTriggered: root.triggered()
            }
        }
    }
}
