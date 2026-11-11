import QtQuick
import qs.core
import qs.widgets

// The title of a guide section with a line of explanation under it.
Column {
    property alias title: title.text
    property alias subtitle: subtitle.text

    spacing: Theme.px(2)

    Txt {
        id: title

        width: parent.width
        size: 24
        bold: true
    }

    Txt {
        id: subtitle

        width: parent.width
        size: 12
        color: Theme.subtext
    }
}
