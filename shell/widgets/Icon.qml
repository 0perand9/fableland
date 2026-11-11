import QtQuick
import qs.core

// A glyph from Icons. `size` is in design units.
//
// The glyph is centred by its ink. An icon font places a glyph by its cell,
// which the drawing overhangs on one side — further in some glyphs than in
// others — so centring the cell would leave the picture visibly off-centre.
Item {
    id: icon

    property string text: ""
    property real size: 18
    property color color: Theme.text

    implicitWidth: Math.ceil(ink.tightBoundingRect.width)
    implicitHeight: glyph.implicitHeight

    Text {
        id: glyph

        x: Math.round((icon.width - ink.tightBoundingRect.width) / 2 - ink.tightBoundingRect.x)
        y: Math.round((icon.height - height) / 2)
        text: icon.text
        color: icon.color
        font.family: Theme.iconFont
        font.pixelSize: Theme.px(icon.size)
        textFormat: Text.PlainText
    }

    TextMetrics {
        id: ink

        font: glyph.font
        text: icon.text
    }
}
