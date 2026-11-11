import QtQuick
import qs.core
import qs.widgets

// The assistant's orb. Nothing answers behind it yet: it wakes up when the
// popup opens — a dull ball winds up and pops into colour — and then idles, breathing.
PopupPage {
    id: page

    // Swings between -1 and 1 every five seconds; whatever breathes follows it.
    property real breath: 0
    // Turns steadily; the dust drifts on it.
    property real drift: 0
    // 0 dull … 1 lit.
    property real awake: 0
    // Jumps to 1 when the orb wakes and ebbs away: the shockwave.
    property real shock: 0

    component Disc: Rectangle {
        anchors.centerIn: parent
        height: width
        radius: width / 2
    }

    // Swings a property between -reach and +reach.
    component Sway: SequentialAnimation {
        id: sway

        property real reach: 1
        property int period: 5000

        loops: Animation.Infinite

        NumberAnimation { to: sway.reach; duration: sway.period / 2; easing.type: Easing.InOutSine }
        NumberAnimation { to: -sway.reach; duration: sway.period / 2; easing.type: Easing.InOutSine }
    }

    implicitWidth: Theme.px(800)
    implicitHeight: Theme.px(650)

    Sway on breath { running: page.visible }
    NumberAnimation on drift { running: page.visible; from: 0; to: 2 * Math.PI; duration: 24000; loops: Animation.Infinite }

    // Waking up: wind up, draw in, pop.
    SequentialAnimation {
        running: true

        PauseAnimation { duration: 200 }
        NumberAnimation { target: orb; property: "rotation"; from: 0; to: 360; duration: 1200; easing.type: Easing.InCubic }
        NumberAnimation { target: orb; property: "scale"; to: 0.96; duration: 250; easing.type: Easing.InOutSine }
        PauseAnimation { duration: 100 }
        ScriptAction { script: pop.restart() }
    }

    ParallelAnimation {
        id: pop

        NumberAnimation { target: page; property: "awake"; to: 1; duration: 300 }
        SequentialAnimation {
            NumberAnimation { target: orb; property: "scale"; to: 1.05; duration: 200; easing.type: Easing.OutCubic }
            NumberAnimation { target: orb; property: "scale"; to: 1; duration: 800; easing.type: Easing.InOutSine }
        }
        SequentialAnimation {
            NumberAnimation { target: page; property: "shock"; to: 1; duration: 150; easing.type: Easing.OutCubic }
            NumberAnimation { target: page; property: "shock"; to: 0; duration: 1200; easing.type: Easing.OutQuart }
        }
    }

    Backdrop {
        anchors.fill: parent
        colors: [Theme.accent, Theme.tertiary]
        strength: 0.1
    }

    // Dust, scattered evenly enough by two primes. Once the orb is awake each
    // mote drifts in a small ellipse; the shockwave pushes them all outwards.
    Repeater {
        model: 20

        Rectangle {
            required property int index
            readonly property real homeX: (index * 113) % 800 / 800 * page.width
            readonly property real homeY: (index * 137) % 650 / 650 * page.height
            readonly property real reach: Theme.px(15) * page.awake

            x: homeX + Math.cos(page.drift * 2 + index * 0.47) * reach + (homeX - page.width / 2) * 0.04 * page.shock
            y: homeY + Math.sin(page.drift * 3 + index * 0.47) * reach + (homeY - page.height / 2) * 0.04 * page.shock
            width: Theme.px(3 + index % 4)
            height: width
            radius: width / 2
            color: index % 3 === 0 ? Theme.tertiary : Theme.accent
            opacity: 0.1 + (index % 3) * 0.1 + 0.2 * page.shock
        }
    }

    Item {
        id: orb

        anchors.centerIn: parent
        width: Theme.px(150)
        height: width

        // The halo: two soft rings that swell with each breath.
        Repeater {
            model: 2

            Disc {
                required property int index

                width: orb.width + Theme.px(20 + index * 40)
                color: Theme.accent
                opacity: (index === 0 ? 0.12 : 0.05) * page.awake * (0.9 + 0.1 * page.breath)
                scale: 1.015 + 0.015 * page.breath
            }
        }

        // The shockwave.
        Disc {
            width: orb.width
            color: Theme.tertiary
            opacity: 0.12 * page.shock
            scale: 1 + 0.8 * page.shock
        }

        // The ball: dull until it wakes, then two gradients swaying against
        // each other inside a rim of light.
        Disc {
            width: orb.width
            gradient: Gradient {
                orientation: Gradient.Horizontal

                GradientStop { position: 0; color: Theme.mix(Theme.surface2, Theme.accent, page.awake) }
                GradientStop { position: 1; color: Theme.mix(Theme.surface0, Theme.tertiary, page.awake) }
            }

            Sway on rotation { reach: 15; period: 12000; running: page.visible }
        }

        Disc {
            width: orb.width
            opacity: 0.8 * page.awake
            border.width: Theme.px(2)
            border.color: Theme.alpha(Theme.text, 0.25 + 0.06 * page.breath)
            gradient: Gradient {
                GradientStop { position: 0; color: Theme.alpha(Theme.tertiary, 0) }
                GradientStop { position: 0.5; color: Theme.tertiary }
                GradientStop { position: 1; color: Theme.alpha(Theme.tertiary, 0) }
            }

            Sway on rotation { reach: -20; period: 14000; running: page.visible }
        }
    }
}
