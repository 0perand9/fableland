import QtQuick
import qs.core
import qs.widgets

// A button of the drawing toolbar. Hovered for a moment, it says what it is
// (and which key does the same); a click sends the tip away until the pointer
// comes back.
IconBtn {
    id: button

    property string tip: ""
    property bool tipDue: false

    size: 36
    iconSize: 19
    iconColor: hovered ? Theme.text : Theme.subtext
    onHoveredChanged: {
        tipDue = false;
        if (hovered)
            patience.restart();
        else
            patience.stop();
    }
    onClicked: {
        tipDue = false;
        patience.stop();
    }

    Timer {
        id: patience

        interval: 450
        onTriggered: button.tipDue = true
    }

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.top
        anchors.bottomMargin: Theme.px(14)
        width: label.implicitWidth + Theme.px(18)
        height: Theme.px(26)
        radius: Theme.radiusSmall
        color: Theme.surface1
        border.width: 1
        border.color: Theme.border
        opacity: button.tipDue && button.tip !== "" ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation { duration: Theme.fast }
        }

        Txt {
            id: label

            anchors.centerIn: parent
            text: button.tip
            size: 11
        }
    }
}
