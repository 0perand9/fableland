import QtQuick
import QtQuick.Effects
import qs.core
import qs.widgets

// Behind the lock screen: the wallpaper out of focus, dimmed, with drifting
// colour and faint rings around the centre.
Item {
    id: root

    // Rings turn red (a rejected password).
    property bool alert: false
    // Somebody is at the keyboard: the colours drift. A lock screen nobody
    // touches stays perfectly still, so it costs nothing for hours.
    property bool lively: false

    Rectangle {
        anchors.fill: parent
        color: Theme.base
    }

    // Decoded at a fraction of the screen, blurred there and stretched back:
    // the blur costs almost nothing and hides the low resolution.
    Image {
        id: wallpaper

        readonly property int shrink: 4

        width: Math.ceil(root.width / shrink)
        height: Math.ceil(root.height / shrink)
        source: Fmt.file(Daemon.wallpaper.current.image ?? "")
        sourceSize: Qt.size(width, height)
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        opacity: status === Image.Ready ? 1 : 0
        transform: Scale {
            xScale: root.width / wallpaper.width
            yScale: root.height / wallpaper.height
        }
        layer.enabled: status === Image.Ready
        layer.smooth: true
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: 1
            blurMax: 32
            // Padding would let the edges fade to transparent.
            autoPaddingEnabled: false
        }

        Behavior on opacity {
            NumberAnimation { duration: Theme.slow }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.alpha(Theme.base, 0.45)
    }

    Blobs {
        anchors.fill: parent
        colors: [Theme.accent, Theme.blue]
        strength: 0.1
        running: root.lively
    }

    Repeater {
        model: 4

        Rectangle {
            required property int index

            anchors.centerIn: parent
            anchors.verticalCenterOffset: -Theme.px(40)
            width: Theme.px(400 + index * 220)
            height: width
            radius: width / 2
            color: "transparent"
            border.width: 1
            border.color: root.alert ? Theme.red : Theme.text
            opacity: root.alert ? 0.3 - index * 0.06 : 0.08 - index * 0.015

            Behavior on border.color {
                ColorAnimation { duration: 600; easing.type: Easing.OutExpo }
            }
            Behavior on opacity {
                NumberAnimation { duration: 600; easing.type: Easing.OutExpo }
            }
        }
    }
}
