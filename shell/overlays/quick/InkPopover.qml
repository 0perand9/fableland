import QtQuick
import qs.core
import qs.widgets

// The ink: ready-made colours, any other colour, and how wide the current
// tool draws. Opens above the drawing toolbar.
Rectangle {
    id: popover

    property color ink
    // The current tool's width in design units, its range and what to call it.
    property real thickness: 4
    property real thinnest: 1
    property real thickest: 24
    property string thicknessLabel: "Width"

    readonly property var swatches: [Theme.red, Theme.peach, Theme.yellow, Theme.green, Theme.sapphire, Theme.mauve, Theme.text, Theme.crust]

    signal inkPicked(color ink)
    signal thicknessPicked(real thickness)

    // "#rrggbb", as typed or pasted — with or without the hash.
    function parse(text) {
        const match = /^#?([0-9a-f]{6})$/i.exec(text.trim());
        if (match)
            inkPicked(Qt.color("#" + match[1]));
        else
            hex.text = String(ink);
    }

    implicitWidth: content.width + 2 * Theme.pad
    implicitHeight: content.height + 2 * Theme.pad
    radius: Theme.radius
    color: Theme.alpha(Theme.base, 0.97)
    border.width: 1
    border.color: Theme.border
    // The field is typed into, so it is refreshed by hand rather than bound.
    onInkChanged: hex.text = String(ink)

    // Clicks on the popover's own background stay here.
    MouseArea {
        anchors.fill: parent
    }

    Column {
        id: content

        x: Theme.pad
        y: Theme.pad
        width: picker.implicitWidth
        spacing: Theme.px(14)

        Row {
            id: swatchRow

            readonly property real dot: Theme.px(22)

            spacing: (parent.width - popover.swatches.length * dot) / (popover.swatches.length - 1)

            Repeater {
                model: popover.swatches

                Rectangle {
                    required property color modelData
                    readonly property bool current: Qt.colorEqual(modelData, popover.ink)

                    width: swatchRow.dot
                    height: width
                    radius: width / 2
                    color: modelData
                    border.width: current ? Theme.px(2) : 1
                    border.color: current ? Theme.text : Theme.alpha(Theme.text, 0.25)
                    scale: swatchTap.pressed ? 0.9 : 1

                    Behavior on scale {
                        NumberAnimation { duration: Theme.fast }
                    }

                    TapHandler {
                        id: swatchTap

                        onTapped: popover.inkPicked(parent.modelData)
                    }

                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                    }
                }
            }
        }

        ColorPicker {
            id: picker

            color: popover.ink
            onPicked: color => popover.inkPicked(color)
        }

        Field {
            id: hex

            width: parent.width
            implicitHeight: Theme.px(36)
            icon: Icons.palette
            size: 12
            clearable: false
            accentColor: popover.ink
            text: String(popover.ink)
            onAccepted: {
                popover.parse(text);
                // Hand the keyboard back to the drawing.
                focus = false;
            }
        }

        Row {
            width: parent.width
            spacing: Theme.px(10)

            Txt {
                id: caption

                anchors.verticalCenter: parent.verticalCenter
                text: popover.thicknessLabel
                size: 12
                color: Theme.subtext
            }

            Slide {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - caption.width - amount.width - 2 * parent.spacing
                from: popover.thinnest
                to: popover.thickest
                value: popover.thickness
                onMoved: value => popover.thicknessPicked(Math.round(value))
            }

            Txt {
                id: amount

                anchors.verticalCenter: parent.verticalCenter
                width: Theme.px(28)
                horizontalAlignment: Text.AlignRight
                text: Math.round(popover.thickness)
                size: 12
                bold: true
            }
        }
    }
}
