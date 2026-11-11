import QtQuick
import qs.core
import qs.widgets

// One flake input: whether it is behind, where it comes from, which revision
// is locked and since when. Clicking it is a wish to see its upstream.
Clickable {
    id: row

    // An entry of `updates.inputs`.
    property var input: ({})
    // When it was locked, in words ("3 days ago"); empty if the lock does not say.
    property string age: ""

    readonly property bool behind: input.status === "behind"
    readonly property bool current: input.status === "current"
    // The repository without its host: "NixOS/nixpkgs". Empty for inputs the daemon cannot look up.
    readonly property string repository: (input.url ?? "").replace(/^https?:\/\/[^\/]+\//, "")

    implicitHeight: Theme.px(58)
    radius: Theme.radius
    fill: behind ? Theme.alpha(Theme.green, 0.12) : Theme.alpha(Theme.surface0, 0.55)
    border.width: 1
    border.color: behind ? Theme.alpha(Theme.green, 0.4) : Theme.border
    interactive: repository !== ""

    Rectangle {
        id: badge

        x: Theme.px(11)
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.px(34)
        height: width
        radius: Theme.px(10)
        color: row.behind ? Theme.green : Theme.alpha(Theme.surface2, 0.6)

        Icon {
            anchors.centerIn: parent
            text: row.behind ? Icons.arrowUp : row.current ? Icons.check : Icons.help
            size: 18
            color: row.behind ? Theme.base : row.current ? Theme.subtext : Theme.yellow
        }
    }

    Column {
        anchors.left: badge.right
        anchors.right: lock.left
        anchors.leftMargin: Theme.px(12)
        anchors.rightMargin: Theme.px(12)
        anchors.verticalCenter: parent.verticalCenter

        Txt {
            width: parent.width
            text: row.input.name ?? ""
            size: 13
            bold: true
        }

        Txt {
            width: parent.width
            text: row.behind || row.current ? row.repository : row.repository !== "" ? row.repository + " · no answer" : "Not on GitHub · not checked"
            size: 11
            color: Theme.subtext
        }
    }

    Column {
        id: lock

        anchors.right: upstream.left
        anchors.rightMargin: Theme.px(8)
        anchors.verticalCenter: parent.verticalCenter

        Row {
            anchors.right: parent.right
            spacing: Theme.px(6)

            Txt {
                text: row.input.rev ?? ""
                size: 12
                color: row.behind ? Theme.dim : Theme.subtext
            }

            Icon {
                visible: row.behind
                anchors.verticalCenter: parent.verticalCenter
                text: Icons.arrowRight
                size: 12
                color: Theme.dim
            }

            Txt {
                visible: row.behind
                text: row.input.latest ?? ""
                size: 12
                bold: true
                color: Theme.green
            }
        }

        Txt {
            anchors.right: parent.right
            visible: row.age !== ""
            text: "locked " + row.age
            size: 11
            color: Theme.dim
        }
    }

    // Shows, under the pointer, that a click leads somewhere.
    Icon {
        id: upstream

        anchors.right: parent.right
        anchors.rightMargin: Theme.px(10)
        anchors.verticalCenter: parent.verticalCenter
        text: Icons.openExternal
        size: 14
        color: Theme.subtext
        opacity: row.hovered ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Theme.fast }
        }
    }
}
