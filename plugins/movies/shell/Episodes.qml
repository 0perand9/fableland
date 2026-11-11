import QtQuick
import qs.core
import qs.widgets

// The season and episode picker of a series. Picking an episode only selects
// it — the Open button (or the arrow on the row) opens it.
Card {
    id: root

    property color hue: Theme.accent

    // Denser than a usual card: it lies on the title's backdrop.
    color: Theme.alpha(Theme.base, 0.78)

    Txt {
        id: heading

        x: Theme.px(18)
        y: Theme.px(16)
        text: Catalog.seasons.length === 1 ? "Episodes" : Catalog.seasons.length + " seasons"
        size: 15
        bold: true
    }

    Txt {
        anchors.right: parent.right
        anchors.rightMargin: Theme.px(18)
        anchors.verticalCenter: heading.verticalCenter
        text: Catalog.seasonEpisodes.length + " episodes"
        size: 12
        color: Theme.subtext
    }

    ListView {
        id: seasons

        anchors.top: heading.bottom
        anchors.topMargin: Theme.px(12)
        x: Theme.px(18)
        width: parent.width - 2 * x
        height: Theme.px(32)
        orientation: ListView.Horizontal
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        spacing: Theme.px(6)
        highlightMoveDuration: Theme.normal
        model: Catalog.seasons
        currentIndex: Catalog.seasons.indexOf(Catalog.season)

        delegate: Chip {
            required property int modelData

            text: "Season " + modelData
            active: modelData === Catalog.season
            hue: root.hue
            onClicked: Catalog.pickSeason(modelData)
        }
    }

    Rectangle {
        id: rule

        anchors.top: seasons.bottom
        anchors.topMargin: Theme.px(12)
        width: parent.width
        height: 1
        color: Theme.border
    }

    List {
        id: episodes

        anchors.top: rule.bottom
        anchors.bottom: parent.bottom
        anchors.margins: Theme.px(8)
        x: Theme.px(8)
        width: parent.width - 2 * x
        model: Catalog.seasonEpisodes
        currentIndex: Catalog.seasonEpisodes.findIndex(e => e.episode === Catalog.episode)

        delegate: Clickable {
            id: row

            required property var modelData
            readonly property bool chosen: modelData.episode === Catalog.episode

            width: episodes.width
            height: Theme.px(46)
            fill: chosen ? Theme.alpha(root.hue, 0.14) : "transparent"
            onClicked: Catalog.episode = modelData.episode

            Rectangle {
                id: number

                x: Theme.px(8)
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.px(32)
                height: Theme.px(32)
                radius: Theme.px(9)
                color: row.chosen ? root.hue : Theme.alpha(Theme.surface2, 0.6)

                Txt {
                    anchors.centerIn: parent
                    text: row.modelData.episode
                    size: 12
                    bold: true
                    color: row.chosen ? Theme.accentText : Theme.subtext
                }
            }

            Txt {
                anchors.left: number.right
                anchors.right: go.left
                anchors.leftMargin: Theme.px(12)
                anchors.rightMargin: Theme.px(8)
                anchors.verticalCenter: parent.verticalCenter
                // Episodes that have not aired yet often come without a name.
                text: row.modelData.title || "Episode " + row.modelData.episode
                size: 13
                color: row.chosen ? Theme.text : Theme.subtext
            }

            IconBtn {
                id: go

                visible: row.hovered || row.chosen
                anchors.right: parent.right
                anchors.rightMargin: Theme.px(6)
                anchors.verticalCenter: parent.verticalCenter
                size: 30
                icon: Icons.openExternal
                iconColor: root.hue
                onClicked: {
                    Catalog.episode = row.modelData.episode;
                    Catalog.open();
                }
            }
        }
    }
}
