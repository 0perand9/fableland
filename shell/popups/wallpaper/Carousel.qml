import QtQuick
import qs.core

// A strip of slanted cards with the focused one opened up in the middle.
//
// Only the cards that can be on screen exist: a fixed ring of slots is reused
// as the strip moves, so a library of any size costs the same. The owner says
// which entry has focus (`index`) and the strip glides there.
Item {
    id: root

    // Library items or online search results (see WallCard.entry).
    property var entries: []
    // The focused entry.
    property int index: 0
    // `path` of the wallpaper on screen and `id` of the result being downloaded: their cards are marked.
    property string currentPath: ""
    property string busyId: ""

    // The user dragged the strip to another entry, or chose one.
    signal picked(int index)
    signal activated(int index)

    readonly property real slant: -0.35
    readonly property real sideWidth: Theme.px(200)
    readonly property real focusWidth: Theme.px(600)
    readonly property real sideHeight: Theme.px(420)
    readonly property real focusHeight: Theme.px(450)
    // Distance from one side card to the next.
    readonly property real pitch: sideWidth + Theme.px(10)
    // How far a card's slanted corners reach beyond its box.
    readonly property real overhang: Math.abs(slant) * focusHeight / 2
    // The picture behind every card: enough for the whole parallelogram of the focused one.
    readonly property size picture: Qt.size(Math.ceil(focusWidth + 2 * overhang), focusHeight)

    // Where the strip is: a fractional entry index that follows `index`.
    property real position: 0
    readonly property int nearest: Math.round(position)
    // Strip coordinate that sits in the middle of the view.
    readonly property real middle: position * pitch + focusWidth / 2
    // Cards kept alive on each side of the middle one.
    readonly property int reach: Math.ceil((width / 2 - focusWidth / 2 + overhang) / pitch) + 1
    readonly property bool resting: !glide.running && !drag.active
    // 0 → 1 while the cards fan out from the middle: on opening and when the list is swapped.
    property real fan: 1

    // Put the strip where `index` says without travelling there (the list changed underneath).
    function snap() {
        glide.stop();
        position = index;
    }

    function deal() {
        fanOut.restart();
    }

    function follow() {
        // A long trip would be a blur of cards loading: start close by instead.
        const far = reach + 1;
        if (Math.abs(index - position) > far)
            position = index - Math.sign(index - position) * far;
        glide.to = index;
        glide.restart();
    }

    // The entry shown by a slot: slots take turns as the strip moves, so a
    // card keeps its entry (and its loaded picture) for as long as it is near.
    function entryOf(slot) {
        const count = 2 * reach + 1, first = nearest - reach;
        return first + ((slot - first) % count + count) % count;
    }

    // Left edge of entry `i` on the strip. Everything is a side card except
    // around `position`, where the focus is shared between two neighbours.
    function leftEdge(i) {
        return i * pitch + (focusWidth - sideWidth) * Math.max(0, Math.min(1, i - position));
    }

    onIndexChanged: follow()

    NumberAnimation {
        id: glide

        target: root
        property: "position"
        duration: 420
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: fanOut

        target: root
        property: "fan"
        from: 0
        to: 1
        duration: Theme.slow
        easing.type: Easing.OutCubic
    }

    Item {
        anchors.fill: parent
        opacity: root.fan

        Repeater {
            model: 2 * root.reach + 1

            WallCard {
                id: card

                required property int index
                readonly property int at: root.entryOf(index)

                entry: root.entries[at] ?? null
                weight: Math.max(0, 1 - Math.abs(at - root.position))
                slant: root.slant
                picture: root.picture
                settled: root.resting && at === root.index
                isCurrent: entry !== null && root.currentPath !== "" && entry.path === root.currentPath
                busy: entry !== null && root.busyId !== "" && entry.id === root.busyId
                width: root.sideWidth + (root.focusWidth - root.sideWidth) * weight
                height: root.sideHeight + (root.focusHeight - root.sideHeight) * weight
                x: root.width / 2 + (root.leftEdge(at) + width / 2 - root.middle) * (0.7 + 0.3 * root.fan) - width / 2
                y: (root.height - height) / 2
                z: weight
                onClicked: root.activated(at)
            }
        }
    }

    DragHandler {
        id: drag

        property real from: 0

        target: null
        yAxis.enabled: false
        onActiveChanged: {
            if (active) {
                glide.stop();
                from = root.position;
            } else {
                root.picked(root.nearest);
                root.follow();
            }
        }
        onActiveTranslationChanged: {
            if (active)
                root.position = Math.max(0, Math.min(root.entries.length - 1, from - activeTranslation.x / root.pitch));
        }
    }
}
