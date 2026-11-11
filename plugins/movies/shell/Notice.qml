import QtQuick
import qs.core
import qs.widgets

// What a list says when it has nothing to show: it is loading, it failed
// (with a way to try again) or there simply is nothing.
Column {
    id: root

    property bool busy: false
    property string icon: Icons.info
    property string text: ""
    // The label of the button under the text, "" for none.
    property string action: ""
    property color hue: Theme.accent

    signal triggered

    spacing: Theme.px(14)

    Spinner {
        anchors.horizontalCenter: parent.horizontalCenter
        visible: root.busy
        implicitWidth: Theme.px(34)
        implicitHeight: Theme.px(34)
        color: root.hue
    }

    Icon {
        anchors.horizontalCenter: parent.horizontalCenter
        visible: !root.busy
        text: root.icon
        size: 40
        color: Theme.dim
    }

    Txt {
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(implicitWidth, Theme.px(560))
        horizontalAlignment: Text.AlignHCenter
        text: root.text
        color: Theme.subtext
        wrapMode: Text.WordWrap
        maximumLineCount: 3
    }

    Btn {
        anchors.horizontalCenter: parent.horizontalCenter
        visible: root.action !== "" && !root.busy
        icon: Icons.refresh
        text: root.action
        onClicked: root.triggered()
    }
}
