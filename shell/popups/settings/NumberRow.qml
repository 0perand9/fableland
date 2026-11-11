import QtQuick
import qs.core
import qs.widgets

// A numeric setting with a stepper; the number can also be typed.
SettingRow {
    id: root

    property real from: 0
    property real to: 100
    property real step: 1
    property int decimals: 0
    property string unit: ""
    // Stored value = shown value × factor (seconds shown, milliseconds stored).
    property real factor: 1
    // What to show instead of 0 when 0 means something ("Never").
    property string zeroLabel: ""

    readonly property real value: rounded(Number(Daemon.setting(path, 0)) / factor)

    function rounded(number) {
        return Number(number.toFixed(decimals));
    }

    function set(number) {
        const next = rounded(Math.max(from, Math.min(to, number)));
        if (next !== value)
            Daemon.setSetting(path, Number((next * factor).toFixed(6)));
    }

    onNudged: by => set(value + by * step)
    onActivated: {
        field.forceActiveFocus();
        field.input.selectAll();
    }

    Row {
        spacing: Theme.px(4)

        IconBtn {
            anchors.verticalCenter: parent.verticalCenter
            icon: Icons.minus
            size: 28
            interactive: root.value > root.from
            onClicked: root.set(root.value - root.step)
        }

        CommitField {
            id: field

            width: Theme.px(66)
            implicitHeight: Theme.px(30)
            value: String(root.value)
            onCommitted: text => {
                const typed = parseFloat(text.replace(",", "."));
                if (isNaN(typed))
                    revert();
                else
                    root.set(typed);
            }

            Binding {
                target: field.input
                property: "horizontalAlignment"
                value: TextInput.AlignHCenter
            }

            // At rest the field reads "5 min" or "Never"; the bare number shows for typing.
            Binding {
                target: field.input
                property: "opacity"
                value: field.activeFocus ? 1 : 0
            }

            Txt {
                anchors.centerIn: parent
                visible: !field.activeFocus
                text: root.value === 0 && root.zeroLabel !== "" ? root.zeroLabel : root.value + (root.unit !== "" ? " " + root.unit : "")
                size: 12
                color: Theme.subtext
            }
        }

        IconBtn {
            anchors.verticalCenter: parent.verticalCenter
            icon: Icons.plus
            size: 28
            interactive: root.value < root.to
            onClicked: root.set(root.value + root.step)
        }
    }
}
