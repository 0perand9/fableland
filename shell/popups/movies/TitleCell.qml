import QtQuick
import qs.core
import qs.widgets

// A title in a grid or a row: its poster with the rating on it, its name and year.
Item {
    id: cell

    // { id, title, poster, year, rating, type }, as the catalogue lists it.
    property var title: ({})
    // Under the keyboard cursor.
    property bool current: false
    // The poster and one line of name only, for rows of small posters.
    property bool compact: false
    property color hue: Theme.accent

    readonly property int inset: Theme.px(8)
    readonly property bool lit: hover.hovered || current
    readonly property string rating: title.rating ?? ""

    signal picked

    HoverHandler {
        id: hover

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: cell.picked()
    }

    Poster {
        id: poster

        x: cell.inset
        y: cell.inset
        width: cell.width - 2 * cell.inset
        height: caption.y - y - Theme.px(8)
        url: cell.title.poster ?? ""
        title: cell.title.title ?? ""
        border.width: cell.lit ? Theme.px(2) : 1
        border.color: cell.lit ? cell.hue : Theme.border
        scale: cell.lit ? 1.03 : 1

        Behavior on scale {
            NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic }
        }

        Rectangle {
            visible: cell.rating !== "" && !cell.compact
            x: Theme.px(7)
            y: Theme.px(7)
            width: score.implicitWidth + Theme.px(12)
            height: Theme.px(22)
            radius: height / 2
            color: Theme.alpha(Theme.base, 0.82)

            Row {
                id: score

                anchors.centerIn: parent
                spacing: Theme.px(3)

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Icons.star
                    size: 11
                    color: cell.hue
                }

                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: cell.rating
                    size: 10
                    bold: true
                }
            }
        }
    }

    Column {
        id: caption

        x: cell.inset
        // The caption keeps its height whatever the name's length, so that posters line up.
        y: cell.height - cell.inset - Theme.px(cell.compact ? 18 : 50)
        width: poster.width

        Txt {
            width: parent.width
            text: cell.title.title ?? ""
            size: 12
            bold: true
            color: cell.lit ? Theme.text : Theme.subtext
            wrapMode: Text.WordWrap
            maximumLineCount: cell.compact ? 1 : 2
        }

        Txt {
            visible: !cell.compact
            width: parent.width
            text: cell.title.year ?? ""
            size: 11
            color: Theme.dim
        }
    }
}
