import QtQuick
import qs.core
import qs.widgets

// A title's poster. Until the picture has arrived — or when there is none —
// the title stands in for it.
RemoteImage {
    id: root

    property string title: ""

    color: Theme.alpha(Theme.surface1, 0.6)

    Txt {
        anchors.centerIn: parent
        width: parent.width - Theme.px(16)
        visible: !root.loaded
        horizontalAlignment: Text.AlignHCenter
        text: root.title
        size: 11
        color: Theme.dim
        wrapMode: Text.WordWrap
        maximumLineCount: 4
    }
}
