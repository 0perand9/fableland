import QtQuick
import qs.core
import qs.widgets

// The applications of the selected day, or of its week, by screen time.
// Clicking one drills into it; the list stays to switch to another.
Card {
    id: root

    // `focus.stats` across all applications.
    property var stats: null
    // Class of the application drilled into ("" = none).
    property string selected: ""
    // 0 the day · 1 its week
    property int scope: 0

    readonly property var apps: (scope === 1 ? stats?.weekApps : stats?.apps) ?? []
    readonly property int selectedIndex: apps.findIndex(app => app.class === selected)
    readonly property string day: stats?.date ?? ""

    signal appSelected(var app)

    // Another day or scope is another list: start it at the top.
    onDayChanged: list.positionViewAtBeginning()
    onScopeChanged: list.positionViewAtBeginning()

    KeyedModel {
        id: entries

        source: root.apps
        key: "class"
    }

    Txt {
        anchors.left: parent.left
        anchors.right: scopes.left
        anchors.leftMargin: Theme.pad
        anchors.rightMargin: Theme.gap
        anchors.verticalCenter: scopes.verticalCenter
        text: entries.count > 0 ? "Applications · " + entries.count : "Applications"
        size: 12
        bold: true
        color: Theme.subtext
    }

    Tabs {
        id: scopes

        anchors.right: parent.right
        anchors.rightMargin: Theme.px(10)
        y: Theme.px(10)
        width: Theme.px(124)
        height: Theme.px(28)
        model: ["Day", "Week"]
        current: root.scope
        size: 11
        onSelected: index => root.scope = index
    }

    Column {
        anchors.centerIn: list
        visible: !!root.stats && entries.count === 0
        spacing: Theme.gap

        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Icons.hourglass
            size: 30
            color: Theme.faint
        }

        Txt {
            text: "No screen time recorded"
            size: 12
            color: Theme.dim
        }
    }

    List {
        id: list

        readonly property real rowHeight: Theme.px(48)

        anchors.fill: parent
        anchors.topMargin: Theme.px(46)
        anchors.bottomMargin: Theme.gap
        anchors.leftMargin: Theme.gap
        anchors.rightMargin: Theme.gap
        model: entries.rows

        displaced: Transition {
            NumberAnimation { property: "y"; duration: Theme.normal; easing.type: Easing.OutCubic }
        }

        delegate: AppRow {
            required property string key

            width: list.width
            height: list.rowHeight
            app: entries.byKey[key] ?? ({})
            onClicked: root.appSelected(app)
        }

        // Declared inside the list, the highlight lives in its content: it
        // scrolls with the rows, underneath them.
        Stretch {
            z: -1
            vertical: true
            width: list.width
            radius: Theme.radiusSmall
            color: Theme.alpha(Theme.accent, 0.16)
            visible: root.selectedIndex >= 0
            targetStart: root.selectedIndex * (list.rowHeight + list.spacing)
            targetEnd: targetStart + list.rowHeight
        }
    }
}
