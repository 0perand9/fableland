import QtQuick
import qs.core
import qs.widgets

// One clipboard entry in full, laid over the grid. It grows out of the entry's
// card and shrinks back into it.
Item {
    id: root

    property bool shown: false
    // The card it grows out of, in this item's coordinates.
    property rect origin: Qt.rect(0, 0, 0, 0)
    property string kind: "text"
    // The whole text (or its start, until the rest has arrived).
    property string text: ""
    // The image's file, for images.
    property string image: ""
    // Said about the entry next to the buttons.
    property string caption: ""

    // Longer texts are cut: laying out megabytes would stall the shell.
    readonly property int textLimit: 20000
    // 0 the card … 1 covering the grid.
    property real reveal: shown ? 1 : 0

    signal copyRequested
    signal dismissed

    // Scroll a text by `delta` pixels (±Infinity: to an end).
    function scrollBy(delta) {
        const from = glide.running ? glide.to : scroll.contentY;
        glide.to = Math.max(0, Math.min(scroll.contentHeight - scroll.height, from + delta));
        glide.restart();
    }

    // Back to the top, at once — for when another entry moves in.
    function rewind() {
        glide.stop();
        scroll.contentY = 0;
    }

    visible: reveal > 0

    Behavior on reveal {
        NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic }
    }

    NumberAnimation {
        id: glide

        target: scroll
        property: "contentY"
        duration: Theme.fast
        easing.type: Easing.OutCubic
    }

    Rectangle {
        x: root.origin.x * (1 - root.reveal)
        y: root.origin.y * (1 - root.reveal)
        width: root.origin.width + (root.width - root.origin.width) * root.reveal
        height: root.origin.height + (root.height - root.origin.height) * root.reveal
        radius: Theme.radius
        color: Theme.crust
        border.width: 1
        border.color: Theme.alpha(Theme.accent, 0.6)
        opacity: Math.min(1, root.reveal * 3)
        clip: true

        // Nothing underneath reacts while the preview is up.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            hoverEnabled: true
            onWheel: wheel => wheel.accepted = true
        }

        // Laid out once at its final size; the growing frame only uncovers it.
        Item {
            width: root.width
            height: root.height
            opacity: root.reveal

            Scroll {
                id: scroll

                anchors.fill: parent
                anchors.margins: Theme.px(20)
                anchors.bottomMargin: bar.height
                visible: root.kind === "text"

                Txt {
                    width: scroll.width
                    text: root.text.length > root.textLimit ? root.text.slice(0, root.textLimit) : root.text
                    size: 13
                    wrapMode: Text.Wrap
                    elide: Text.ElideNone
                    lineHeight: 1.2
                }
            }

            RoundImage {
                anchors.fill: scroll
                visible: root.kind === "image"
                radius: Theme.px(8)
                color: "transparent"
                source: root.kind === "image" ? Fmt.file(root.image) : ""
                fillMode: Image.PreserveAspectFit
            }

            Item {
                id: bar

                anchors.bottom: parent.bottom
                width: parent.width
                height: Theme.px(56)

                Icon {
                    id: kindIcon

                    x: Theme.px(20)
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.kind === "image" ? Icons.image : Icons.text
                    size: 16
                    color: Theme.accent
                }

                Txt {
                    anchors.left: kindIcon.right
                    anchors.leftMargin: Theme.px(10)
                    anchors.right: actions.left
                    anchors.rightMargin: Theme.px(12)
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.caption
                    size: 12
                    color: Theme.subtext
                }

                Row {
                    id: actions

                    anchors.right: parent.right
                    anchors.rightMargin: Theme.px(14)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.px(8)

                    Btn {
                        text: "Copy"
                        icon: Icons.copy
                        kind: "filled"
                        onClicked: root.copyRequested()
                    }

                    IconBtn {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: Icons.close
                        onClicked: root.dismissed()
                    }
                }
            }
        }
    }
}
