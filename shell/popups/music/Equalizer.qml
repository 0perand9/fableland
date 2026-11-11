import QtQuick
import QtQuick.Shapes
import qs.core
import qs.widgets

// The system equalizer (EasyEffects): one slider per band, the presets, and
// "Apply" for band changes, which the daemon holds as pending until then.
// Presets take effect at once. Says so when EasyEffects is not installed.
Column {
    id: root

    readonly property var eq: Daemon.eq
    // The preset names as one string, so the tabs are rebuilt only when the set
    // of presets changes, not on every band move.
    readonly property string presetKey: (eq.presetNames ?? []).join("\n")
    readonly property var presetNames: presetKey === "" ? [] : presetKey.split("\n")
    // The settings in effect; changes whenever the daemon reports newly applied ones.
    readonly property string appliedKey: eq.pending ? "" : eq.preset + " " + eq.bands.join(" ")
    readonly property color hue: eq.pending ? Theme.yellow : Theme.accent

    // Position of the sweep that runs across the bands when settings take effect,
    // in bands, and the afterglow it leaves on the curve.
    property real sweep: -1
    property real afterglow: 0

    // A smooth line through the knobs: the shape of the sound.
    readonly property var curve: {
        const knobs = [];
        for (let i = 0; i < bands.built; i++) {
            const band = bands.itemAt(i);
            if (band)
                knobs.push(Qt.point(band.x + band.width / 2, band.knobY));
        }
        return eased(knobs);
    }

    // Points along a line that eases from each knob to the next.
    function eased(knobs) {
        const steps = 8, points = [];
        for (let i = 0; i + 1 < knobs.length; i++) {
            const from = knobs[i], to = knobs[i + 1];
            for (let s = 0; s < steps; s++) {
                const t = s / steps;
                points.push(Qt.point(from.x + (to.x - from.x) * t, from.y + (to.y - from.y) * (1 - Math.cos(Math.PI * t)) / 2));
            }
        }
        if (knobs.length > 0)
            points.push(knobs[knobs.length - 1]);
        return points;
    }

    // 31 → "31", 1000 → "1k"
    function frequencyLabel(hz) {
        return hz >= 1000 ? Math.round(hz / 100) / 10 + "k" : String(Math.round(hz ?? 0));
    }

    spacing: Theme.px(14)
    onAppliedKeyChanged: {
        if (appliedKey !== "")
            applied.restart();
    }

    ParallelAnimation {
        id: applied

        NumberAnimation { target: root; property: "sweep"; from: -1; to: root.eq.bands.length; duration: 700; easing.type: Easing.OutSine }
        NumberAnimation { target: root; property: "afterglow"; from: 1; to: 0; duration: 1400; easing.type: Easing.OutQuad }
    }

    Item {
        width: parent.width
        height: Theme.px(32)

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.px(10)

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                text: Icons.equalizer
                size: 20
                color: root.eq.available ? Theme.accent : Theme.dim
            }

            Txt {
                anchors.verticalCenter: parent.verticalCenter
                text: "Equalizer"
                size: 16
                bold: true
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: root.eq.available
            spacing: Theme.px(12)

            Txt {
                anchors.verticalCenter: parent.verticalCenter
                text: root.eq.pending ? root.eq.preset + " · not applied yet" : root.eq.preset
                size: 12
                color: root.eq.pending ? Theme.yellow : Theme.subtext
            }

            Btn {
                height: Theme.px(30)
                text: root.eq.pending ? "Apply" : "Applied"
                icon: root.eq.pending ? "" : Icons.check
                size: 12
                kind: root.eq.pending ? "filled" : "tonal"
                interactive: root.eq.pending
                onClicked: Daemon.send("eq.apply")
            }
        }
    }

    Card {
        visible: !root.eq.available
        width: parent.width
        implicitHeight: Theme.px(68)

        Icon {
            id: missing

            x: Theme.pad
            anchors.verticalCenter: parent.verticalCenter
            text: Icons.info
            size: 22
            color: Theme.dim
        }

        Column {
            anchors.left: missing.right
            anchors.right: parent.right
            anchors.leftMargin: Theme.px(12)
            anchors.rightMargin: Theme.pad
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.px(2)

            Txt {
                width: parent.width
                text: "EasyEffects is not installed"
                size: 13
                bold: true
            }

            Txt {
                width: parent.width
                text: "The equalizer works through EasyEffects — install it to shape the sound here."
                size: 11
                color: Theme.subtext
            }
        }
    }

    Item {
        id: bandArea

        visible: root.eq.available
        width: parent.width
        height: Theme.px(190)

        // 0 dB.
        Rectangle {
            y: Math.round(bandArea.height / 2)
            width: parent.width
            height: 1
            color: Theme.border
        }

        Shape {
            anchors.fill: parent
            visible: root.curve.length > 1
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: Theme.alpha(root.hue, 0.3 + 0.6 * root.afterglow)
                strokeWidth: Theme.px(2)
                fillColor: "transparent"
                joinStyle: ShapePath.RoundJoin

                PathPolyline {
                    path: root.curve
                }
            }
        }

        Row {
            anchors.fill: parent

            Repeater {
                id: bands

                // Counts the bands that exist, so that `curve` (which reads them
                // through itemAt(), not a binding dependency) follows.
                property int built: 0

                model: root.eq.bands.length
                onItemAdded: built++
                onItemRemoved: built--

                EqBand {
                    required property int index

                    width: bandArea.width / bands.count
                    height: bandArea.height
                    value: root.eq.bands[index] ?? 0
                    label: root.frequencyLabel(root.eq.frequencies[index])
                    accentColor: root.hue
                    flash: Math.max(0, 1 - Math.abs(root.sweep - index))
                    onMoved: gain => Daemon.stream("eq-band-" + index, "eq.setBand", { index: index, gain: gain })
                }
            }
        }
    }

    Tabs {
        visible: root.eq.available
        width: parent.width
        model: root.presetNames
        current: root.presetNames.indexOf(root.eq.preset)
        size: 12
        onSelected: index => Daemon.send("eq.preset", { name: root.presetNames[index] })
    }
}
