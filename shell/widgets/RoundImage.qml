import QtQuick
import Quickshell.Widgets
import qs.core

// An image cropped to fill a rounded box. `source` takes a URL — wrap local
// paths with Fmt.file(). Decoded at display size, off the UI thread.
ClippingRectangle {
    id: root

    property alias source: image.source
    property alias fillMode: image.fillMode
    property alias image: image
    readonly property bool loaded: image.status === Image.Ready

    radius: Theme.radiusSmall
    color: Theme.alpha(Theme.surface1, 0.5)

    Image {
        id: image

        anchors.fill: parent
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: Math.ceil(root.width)
        sourceSize.height: Math.ceil(root.height)
        opacity: status === Image.Ready ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Theme.normal }
        }
    }
}
