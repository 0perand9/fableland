import QtQuick
import qs.core
import qs.widgets

// One wallpaper in the carousel: a slanted window onto its picture. The
// picture keeps one size however wide the card is, so a card that gains focus
// opens up and shows more of it instead of rescaling it.
Item {
    id: card

    // A library item or an online search result; null hides the card.
    property var entry: null
    // 0 for a side card … 1 for the focused one.
    property real weight: 0
    // Horizontal shift per unit of height.
    property real slant: 0
    // Size of the picture behind the card's opening.
    property size picture: Qt.size(0, 0)
    // The card is focused and has come to rest: worth loading the sharp image or the video.
    property bool settled: false
    // This is the wallpaper on screen right now.
    property bool isCurrent: false
    // Being downloaded.
    property bool busy: false

    readonly property bool video: entry?.video ?? false
    readonly property color tint: entry?.color ?? Theme.surface2
    readonly property int frame: Theme.px(3)
    // Side cards brighten under the pointer.
    property real lift: hover.hovered ? 1 : 0

    signal clicked

    // Content that must not lean with the card.
    component Upright: Item {
        id: upright

        property real slant: 0

        transform: Shear {
            xFactor: -upright.slant
            origin.y: upright.height / 2
        }
    }

    // A small marker in a corner of the card.
    component Badge: Upright {
        id: badge

        property string icon: ""
        property color fill: Theme.alpha(Theme.base, 0.7)
        property color ink: Theme.text

        width: Theme.px(30)
        height: width

        Rectangle {
            anchors.fill: parent
            radius: Theme.px(9)
            color: badge.fill

            Icon {
                anchors.centerIn: parent
                text: badge.icon
                size: 18
                color: badge.ink
            }
        }
    }

    visible: entry !== null
    opacity: Math.min(1, 0.6 + 0.4 * weight + 0.3 * lift)
    // Slanted about the vertical centre, so that neighbours of any height line up.
    transform: Shear {
        xFactor: card.slant
        origin.y: card.height / 2
    }

    Behavior on lift {
        NumberAnimation { duration: Theme.fast }
    }

    // The opening: everything inside is cut to the card's parallelogram.
    Item {
        id: opening

        anchors.fill: parent
        // One pixel under the frame, which hides the opening's unsmoothed edge.
        anchors.margins: card.frame - 1
        clip: true

        Rectangle {
            anchors.fill: parent
            color: Theme.mix(Theme.surface0, card.tint, 0.3)
        }

        Upright {
            anchors.centerIn: parent
            width: card.picture.width
            height: card.picture.height
            slant: card.slant

            Image {
                anchors.fill: parent
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
                sourceSize: card.picture
                source: Fmt.file(card.entry?.thumb ?? "")
                opacity: status === Image.Ready ? 1 : 0

                Behavior on opacity {
                    NumberAnimation { duration: Theme.normal }
                }
            }

            // Thumbnails are small; the focused card gets the real image once it rests.
            Image {
                anchors.fill: parent
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
                sourceSize: card.picture
                source: card.settled && !card.video ? Fmt.file(card.entry?.path ?? "") : ""
                opacity: status === Image.Ready ? 1 : 0

                Behavior on opacity {
                    NumberAnimation { duration: Theme.normal }
                }
            }

            Loader {
                id: preview

                readonly property bool playing: item?.playing ?? false

                anchors.fill: parent
                active: card.settled && card.video
                source: Qt.resolvedUrl("VideoPreview.qml")
                onLoaded: item.source = Fmt.file(card.entry.path)
            }
        }

        Rectangle {
            anchors.fill: parent
            visible: card.busy
            color: Theme.alpha(Theme.base, 0.6)

            Upright {
                anchors.centerIn: parent
                width: Theme.px(34)
                height: width
                slant: card.slant

                Spinner {
                    anchors.fill: parent
                    running: card.busy
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        antialiasing: true
        color: "transparent"
        border.width: card.frame
        border.color: Theme.mix(card.tint, Theme.accent, card.weight)
    }

    Badge {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: Theme.px(14)
        visible: card.isCurrent
        slant: card.slant
        icon: Icons.check
        fill: Theme.accent
        ink: Theme.accentText
    }

    Badge {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: Theme.px(14)
        visible: card.video && !preview.playing
        slant: card.slant
        icon: Icons.play
    }

    HoverHandler {
        id: hover

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: card.clicked()
    }
}
