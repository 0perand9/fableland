import QtQuick
import qs.core

// Text in the shell's font. `size` is in design units.
Text {
    property real size: 14
    property bool bold: false

    color: Theme.text
    font.family: Theme.font
    font.pixelSize: Theme.px(size)
    font.weight: bold ? Font.Bold : Font.Medium
    elide: Text.ElideRight
    textFormat: Text.PlainText
    verticalAlignment: Text.AlignVCenter
}
