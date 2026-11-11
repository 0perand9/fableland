import QtQuick
import qs.core
import qs.widgets

// One title in full: backdrop, poster, what it is about and who is in it, the
// seasons and episodes of a series, and the button that opens it with the
// link from the `movies.openWith` setting.
//
// Keys: Enter opens; for a series Up/Down pick the episode and Tab the season.
FocusScope {
    id: view

    property color hue: Theme.accent

    readonly property var title: Catalog.selected ?? ({})
    readonly property var details: Catalog.details
    readonly property bool hasEpisodes: Catalog.episodes.length > 0
    // Where the content starts, below the Back button.
    readonly property int panelTop: back.y + back.height + Theme.px(20)
    readonly property var facts: [
        { icon: Icons.calendar, text: fact("year") },
        { icon: Icons.star, text: fact("rating") },
        { icon: Icons.clock, text: fact("runtime") }
    ].filter(entry => entry.text !== "")
    // Where the Open button leads: the host of the link template.
    readonly property string site: {
        const host = /^[a-z]+:\/\/([^\/?#]+)/i.exec(Daemon.setting("movies.openWith", ""));
        return host ? host[1].replace(/^www\./, "") : "";
    }

    // The list entry already knows some of what the details will say.
    function fact(name) {
        return String((details ? details[name] : null) ?? title[name] ?? "");
    }

    function stepEpisode(by) {
        const list = Catalog.seasonEpisodes;
        const next = list[Math.max(0, Math.min(list.length - 1, list.findIndex(e => e.episode === Catalog.episode) + by))];
        if (next)
            Catalog.episode = next.episode;
    }

    function stepSeason(by) {
        const seasons = Catalog.seasons;
        if (seasons.length > 0)
            Catalog.pickSeason(seasons[(seasons.indexOf(Catalog.season) + by + seasons.length) % seasons.length]);
    }

    Keys.onUpPressed: stepEpisode(-1)
    Keys.onDownPressed: stepEpisode(1)
    Keys.onTabPressed: stepSeason(1)
    Keys.onBacktabPressed: stepSeason(-1)
    Keys.onReturnPressed: {
        if (openButton.interactive)
            Catalog.open();
    }

    Image {
        readonly property string url: view.details?.background ?? ""

        anchors.fill: parent
        source: Fmt.file(Pictures.paths[url] ?? "")
        onUrlChanged: Pictures.fetch(url)
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: width
        sourceSize.height: height
        opacity: status === Image.Ready ? 0.85 : 0

        Behavior on opacity {
            NumberAnimation { duration: Theme.slow }
        }
    }

    // Keeps the text readable on any backdrop: solid on the left, clearing towards the right.
    Rectangle {
        anchors.fill: parent

        gradient: Gradient {
            orientation: Gradient.Horizontal

            GradientStop { position: 0; color: Theme.alpha(Theme.base, 0.97) }
            GradientStop { position: 0.45; color: Theme.alpha(Theme.base, 0.86) }
            GradientStop { position: 1; color: Theme.alpha(Theme.base, 0.3) }
        }
    }

    Btn {
        id: back

        x: Theme.px(24)
        y: Theme.px(20)
        icon: Icons.arrowLeft
        text: "Back"
        onClicked: Catalog.back()
    }

    Column {
        id: info

        // Centred in the room below the Back button.
        y: Math.max(panelTop, panelTop + (view.height - panelTop - height) / 2 - Theme.px(16))
        x: Theme.px(40)
        width: Theme.px(view.hasEpisodes ? 640 : 860)
        spacing: Theme.px(22)

        Row {
            width: parent.width
            spacing: Theme.px(26)

            Poster {
                id: poster

                width: Theme.px(220)
                height: Theme.px(330)
                radius: Theme.radius
                border.width: 1
                border.color: Theme.border
                url: view.title.poster ?? ""
                title: view.title.title ?? ""
            }

            Column {
                width: parent.width - poster.width - parent.spacing
                spacing: Theme.px(14)

                Txt {
                    width: parent.width
                    text: view.fact("title")
                    size: 30
                    bold: true
                    wrapMode: Text.WordWrap
                    maximumLineCount: 3
                    lineHeight: 1.1
                }

                Row {
                    spacing: Theme.px(18)

                    Repeater {
                        model: view.facts

                        Row {
                            required property var modelData

                            spacing: Theme.px(6)

                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                text: parent.modelData.icon
                                size: 16
                                color: view.hue
                            }

                            Txt {
                                anchors.verticalCenter: parent.verticalCenter
                                text: parent.modelData.text
                                size: 14
                                color: Theme.subtext
                            }
                        }
                    }
                }

                Flow {
                    width: parent.width
                    spacing: Theme.px(8)

                    Repeater {
                        model: view.details?.genres ?? []

                        Chip {
                            required property string modelData

                            text: modelData
                            interactive: false
                        }
                    }
                }

                Txt {
                    readonly property var cast: view.details?.cast ?? []

                    visible: cast.length > 0
                    width: parent.width
                    text: "With " + cast.join(", ")
                    size: 13
                    color: Theme.subtext
                    wrapMode: Text.WordWrap
                    maximumLineCount: 3
                    lineHeight: 1.2
                }

                Row {
                    visible: Catalog.detailsLoading
                    spacing: Theme.px(10)

                    Spinner {
                        color: view.hue
                    }

                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Fetching the details…"
                        size: 13
                        color: Theme.subtext
                    }
                }
            }
        }

        Txt {
            visible: text !== ""
            width: parent.width
            text: view.details?.description ?? ""
            size: 14
            wrapMode: Text.WordWrap
            maximumLineCount: 7
            lineHeight: 1.3
        }

        Notice {
            visible: Catalog.detailsError !== ""
            anchors.horizontalCenter: parent.horizontalCenter
            icon: Icons.error
            text: "The catalogue did not answer: " + Catalog.detailsError
            action: "Try again"
            onTriggered: Catalog.loadDetails()
        }

        Row {
            spacing: Theme.px(10)

            Btn {
                id: openButton

                kind: "filled"
                accentColor: view.hue
                icon: Icons.play
                text: view.hasEpisodes ? "Open S" + Catalog.season + " · E" + Catalog.episode : "Open"
                size: 14
                // A series needs its episodes before one can be opened.
                interactive: !Catalog.detailsLoading && view.site !== ""
                onClicked: Catalog.open()
            }

            Btn {
                icon: Icons.openExternal
                text: "IMDb"
                size: 14
                onClicked: Daemon.send("misc.open", { target: "https://www.imdb.com/title/" + view.title.id + "/" })
            }
        }

        Row {
            spacing: Theme.px(8)

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                text: Icons.link
                size: 15
                color: Theme.dim
            }

            Txt {
                anchors.verticalCenter: parent.verticalCenter
                text: view.site !== "" ? "Opens with " + view.site + ". The link is yours to change:" : "No link to open titles with is set:"
                size: 12
                color: Theme.dim
            }

            Btn {
                anchors.verticalCenter: parent.verticalCenter
                height: Theme.px(28)
                kind: "flat"
                accentColor: view.hue
                text: "Settings › Movies"
                size: 12
                onClicked: Ui.open("settings", "movies")
            }
        }
    }

    Episodes {
        visible: view.hasEpisodes
        anchors.left: info.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.leftMargin: Theme.px(36)
        anchors.rightMargin: Theme.px(28)
        anchors.topMargin: view.panelTop
        anchors.bottomMargin: Theme.px(28)
        hue: view.hue
    }
}
