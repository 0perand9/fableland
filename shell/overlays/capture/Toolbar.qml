import QtQuick
import qs.core
import qs.widgets

// The pill next to the selection: screenshot or recording, a choice that goes
// with it (what to do with the screenshot, which sound to record), the
// whole-screen toggle, confirm and cancel.
Rectangle {
    id: root

    property bool recording: false
    // Offer the switch between screenshot and recording.
    property bool canSwitchMode: false
    // [{ key, label, icon }] and the key of the one that is picked.
    property var choices: []
    property string choice: ""
    // The selection covers the whole screen.
    property bool full: false
    property color hue: Theme.accent

    signal modeSwitched
    signal chosen(string key)
    signal fullToggled
    signal confirmed
    signal cancelled

    implicitWidth: row.implicitWidth + Theme.px(16)
    implicitHeight: Theme.px(52)
    radius: height / 2
    color: Theme.alpha(Theme.base, 0.94)
    border.width: 1
    border.color: Theme.border

    // A click on the toolbar is not a click on the screen under it.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: Theme.px(6)

        Tabs {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.canSwitchMode
            width: Theme.px(88)
            height: Theme.px(36)
            model: [{ icon: Icons.camera }, { icon: Icons.video }]
            current: root.recording ? 1 : 0
            accentColor: root.hue
            onSelected: index => {
                if (index !== current)
                    root.modeSwitched();
            }
        }

        Tabs {
            anchors.verticalCenter: parent.verticalCenter
            // Nothing to choose from with a single option.
            visible: root.choices.length > 1
            width: root.choices.length * Theme.px(96)
            height: Theme.px(36)
            size: 12
            model: root.choices
            current: root.choices.findIndex(c => c.key === root.choice)
            accentColor: root.hue
            onSelected: index => root.chosen(root.choices[index].key)
        }

        IconBtn {
            anchors.verticalCenter: parent.verticalCenter
            icon: root.full ? Icons.collapse : Icons.fullscreen
            size: 36
            iconColor: Theme.subtext
            onClicked: root.fullToggled()
        }

        Btn {
            anchors.verticalCenter: parent.verticalCenter
            kind: "filled"
            radius: height / 2
            text: root.recording ? "Record" : "Capture"
            icon: root.recording ? Icons.recordDot : Icons.check
            accentColor: root.hue
            onClicked: root.confirmed()
        }

        IconBtn {
            anchors.verticalCenter: parent.verticalCenter
            icon: Icons.close
            size: 36
            iconColor: Theme.subtext
            onClicked: root.cancelled()
        }
    }
}
