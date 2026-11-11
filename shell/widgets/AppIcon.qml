import QtQuick
import Quickshell.Widgets
import qs.core

// An application or theme icon by name or path, with a glyph when the icon
// theme has nothing by that name. `size` is in design units.
Item {
    id: root

    property string icon: ""
    // Tried when `icon` is not found.
    property string fallback: ""
    property string glyph: Icons.apps
    property color glyphColor: Theme.subtext
    property real size: 24

    readonly property string source: Fmt.icon(icon) || Fmt.icon(fallback)

    implicitWidth: Theme.px(size)
    implicitHeight: Theme.px(size)

    IconImage {
        anchors.centerIn: parent
        visible: root.source !== ""
        // The size the icon is rendered at; without it scalable icons are drawn far too large first.
        implicitSize: Math.min(root.width, root.height)
        source: root.source
        asynchronous: true
    }

    Icon {
        anchors.centerIn: parent
        visible: root.source === ""
        text: root.glyph
        size: root.size * 0.8
        color: root.glyphColor
    }
}
