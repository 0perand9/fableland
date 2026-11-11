import QtQuick
import qs.core
import qs.widgets
import qs.plugins.movies

// A browser for the film and series catalogue: what is trending, a search, a
// title's details — and a button that opens the title with a link of the
// user's choosing (the `movies.openWith` setting). Nothing is played here.
PopupPage {
    id: page

    readonly property bool detailed: Catalog.selected !== null
    // Movies and series each have their own tint.
    readonly property color hue: Catalog.type === "series" ? Theme.tertiary : Theme.accent

    implicitWidth: Theme.px(1370)
    implicitHeight: Theme.px(850)
    placement: "bottom"
    Component.onCompleted: Catalog.enter()
    // Escape leaves a title's details before it closes the popup.
    Keys.onEscapePressed: event => {
        if (detailed)
            Catalog.back();
        else
            event.accepted = false;
    }

    Connections {
        target: Catalog

        // The title is on its way to the browser; step aside.
        function onOpened() {
            page.close();
        }
    }

    Backdrop {
        anchors.fill: parent
        colors: [page.hue, Theme.secondary, Theme.accent]
        running: visible && !page.detailed
    }

    Browse {
        anchors.fill: parent
        visible: !page.detailed
        focus: !page.detailed
        hue: page.hue
    }

    // Built only while a title is on show.
    Loader {
        anchors.fill: parent
        active: page.detailed
        focus: page.detailed

        sourceComponent: Details {
            focus: true
            hue: page.hue
        }
    }

    // Why opening a title or forgetting a search did not work.
    Rectangle {
        id: problem

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.px(20)
        width: Math.min(parent.width - Theme.px(80), message.implicitWidth + Theme.px(86))
        height: Theme.px(44)
        radius: height / 2
        color: Theme.mix(Theme.base, Theme.red, 0.18)
        border.width: 1
        border.color: Theme.alpha(Theme.red, 0.6)
        visible: opacity > 0
        opacity: Catalog.problem !== "" ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Theme.normal }
        }

        Icon {
            id: sign

            x: Theme.px(14)
            anchors.verticalCenter: parent.verticalCenter
            text: Icons.error
            size: 18
            color: Theme.red
        }

        Txt {
            id: message

            anchors.left: sign.right
            anchors.right: dismiss.left
            anchors.leftMargin: Theme.px(10)
            anchors.rightMargin: Theme.px(6)
            anchors.verticalCenter: parent.verticalCenter
            // The text stays while the banner fades out.
            text: Catalog.problem || text
            size: 13
        }

        IconBtn {
            id: dismiss

            anchors.right: parent.right
            anchors.rightMargin: Theme.px(8)
            anchors.verticalCenter: parent.verticalCenter
            size: 28
            icon: Icons.close
            iconColor: Theme.subtext
            onClicked: Catalog.problem = ""
        }

        // The banner leaves by itself after a while.
        Timer {
            interval: 6000
            running: Catalog.problem !== ""
            onTriggered: Catalog.problem = ""
        }
    }
}
