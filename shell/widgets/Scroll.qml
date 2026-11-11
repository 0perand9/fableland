import QtQuick
import qs.core

// A vertically scrolling area for free-form content:
//   Scroll { Column { width: parent.width; ... } }
Flickable {
    id: root

    default property alias content: holder.data

    clip: true
    boundsBehavior: Flickable.StopAtBounds
    contentWidth: width
    contentHeight: holder.childrenRect.height

    Item {
        id: holder

        width: root.width
        height: childrenRect.height
    }

    Scroller {
        parent: root
        target: root
        x: root.width - width - Theme.px(2)
        y: root.visibleArea.yPosition * root.height
    }
}
