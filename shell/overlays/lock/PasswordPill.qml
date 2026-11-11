import QtQuick
import qs.core
import qs.widgets

// The password as a row of dots. With the setting `lock.hidePassword` off,
// each character shows for `lock.revealMs` before it turns into its dot.
Rectangle {
    id: root

    property string text: ""
    property bool busy: false
    property bool failed: false

    readonly property bool hide: Daemon.setting("lock.hidePassword", true)
    readonly property int revealMs: Daemon.setting("lock.revealMs", 600)
    readonly property color ink: failed ? Theme.red : busy ? Theme.accent : Theme.text

    function shake() {
        shakeAnimation.restart();
    }

    // Keep the characters that are still there (and their reveal state), replace the rest.
    function sync() {
        const typed = Array.from(text);
        let same = 0;
        while (same < glyphs.count && same < typed.length && glyphs.get(same).glyph === typed[same])
            same++;
        if (same < glyphs.count)
            glyphs.remove(same, glyphs.count - same);
        for (let i = same; i < typed.length; i++)
            glyphs.append({ glyph: typed[i] });
    }

    implicitWidth: Theme.px(280)
    implicitHeight: Theme.px(60)
    radius: height / 2
    color: failed ? Theme.alpha(Theme.red, 0.12) : Theme.alpha(Theme.surface0, 0.55)
    border.width: Theme.px(2)
    border.color: failed || busy || text !== "" ? ink : Theme.border
    scale: failed ? 1.04 : busy ? 0.98 : 1
    transform: Translate {
        id: offset
    }
    onTextChanged: sync()
    Component.onCompleted: sync()

    Behavior on color {
        ColorAnimation { duration: Theme.normal }
    }
    Behavior on border.color {
        ColorAnimation { duration: Theme.normal }
    }
    Behavior on scale {
        NumberAnimation { duration: 300; easing.type: Easing.OutBack }
    }

    SequentialAnimation {
        id: shakeAnimation

        NumberAnimation { target: offset; property: "x"; to: -Theme.px(10); duration: 70; easing.type: Easing.OutSine }
        NumberAnimation { target: offset; property: "x"; to: Theme.px(10); duration: 110; easing.type: Easing.InOutSine }
        NumberAnimation { target: offset; property: "x"; to: -Theme.px(6); duration: 100; easing.type: Easing.InOutSine }
        NumberAnimation { target: offset; property: "x"; to: 0; duration: 90; easing.type: Easing.OutSine }
    }

    ListModel {
        id: glyphs
    }

    Txt {
        anchors.centerIn: parent
        text: "Password"
        size: 14
        color: Theme.dim
        opacity: root.text === "" ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Theme.fast }
        }
    }

    Item {
        id: viewport

        anchors.fill: parent
        anchors.leftMargin: Theme.px(22)
        anchors.rightMargin: Theme.px(22)
        clip: true

        Row {
            // Centred while it fits; a long password keeps its newest end in view.
            x: Math.min(viewport.width - width, (viewport.width - width) / 2)
            height: parent.height

            Behavior on x {
                NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic }
            }

            Repeater {
                model: glyphs

                Item {
                    id: cell

                    required property string glyph
                    property bool expired: false
                    readonly property bool masked: root.hide || expired

                    width: Theme.px(18)
                    height: parent.height

                    Timer {
                        interval: root.revealMs
                        running: !cell.masked
                        onTriggered: cell.expired = true
                    }

                    NumberAnimation on scale {
                        from: 0
                        to: 1
                        duration: 180
                        easing.type: Easing.OutBack
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        visible: cell.masked
                        width: Theme.px(10)
                        height: width
                        radius: width / 2
                        color: root.ink
                    }

                    Txt {
                        anchors.centerIn: parent
                        visible: !cell.masked
                        text: cell.glyph
                        size: 20
                        bold: true
                        color: root.ink
                    }
                }
            }
        }
    }
}
