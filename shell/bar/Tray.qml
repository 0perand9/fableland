import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.core
import qs.widgets

// System tray icons: left click activates, middle click is the secondary
// action, right click opens the item's menu.
BarGroup {
    id: root

    required property var window

    visible: SystemTray.items.values.length > 0
    padding: Theme.px(8)
    spacing: Theme.px(2)

    Repeater {
        model: SystemTray.items

        Clickable {
            id: item

            required property var modelData

            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: Theme.px(30)
            implicitHeight: Theme.px(30)
            radius: Theme.px(8)
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            onClicked: mouse => {
                if (mouse.button === Qt.MiddleButton)
                    modelData.secondaryActivate();
                else if (mouse.button === Qt.RightButton || modelData.onlyMenu)
                    modelData.hasMenu ? menu.open() : modelData.activate();
                else
                    modelData.activate();
            }
            onWheel: wheel => modelData.scroll(wheel.angleDelta.y, false)

            IconImage {
                anchors.centerIn: parent
                implicitSize: Theme.px(18)
                source: item.modelData.icon
            }

            QsMenuAnchor {
                id: menu

                anchor.window: root.window
                anchor.item: item
                menu: item.modelData.menu
            }
        }
    }
}
