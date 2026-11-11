import QtQuick
import Quickshell
import qs.core
import qs.widgets

// What one screen shows while the session is locked: a big clock that gives
// way to the password prompt on the first key press or click, a row of status
// pills and the power menu. Nothing in here can unlock — it only feeds `auth`.
Item {
    id: root

    required property Auth auth

    // This screen shows the prompt instead of the clock.
    property bool awake: false
    readonly property bool prompting: awake || auth.password !== "" || auth.checking
    property bool capsLock: false

    // The clock and the prompt take turns in the middle of the screen. This is
    // the point either one is centred on: the one that leaves drifts `away`
    // (design units from the centre), shrinking and fading.
    component Turn: Item {
        property bool shown: true
        property real away: 0

        anchors.centerIn: parent
        anchors.verticalCenterOffset: Theme.px(shown ? -40 : away)
        opacity: shown ? 1 : 0
        scale: shown ? 1 : 0.9
        visible: opacity > 0

        Behavior on anchors.verticalCenterOffset {
            NumberAnimation { duration: 500; easing.type: Easing.OutExpo }
        }
        Behavior on opacity {
            NumberAnimation { duration: Theme.slow; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
            NumberAnimation { duration: 500; easing.type: Easing.OutBack }
        }
    }

    function wake() {
        awake = true;
        // Already counting down: start over.
        if (doze.running)
            doze.restart();
        field.forceActiveFocus();
    }

    function keyPressed(event) {
        noteCapsLock(event);
        power.open = false;
        const escape = event.key === Qt.Key_Escape;
        const clearLine = event.key === Qt.Key_U && (event.modifiers & Qt.ControlModifier);
        // The space bar that wakes the screen is not part of the password.
        const wakingSpace = event.key === Qt.Key_Space && !prompting;
        if (escape || clearLine)
            auth.reset();
        if (escape)
            awake = false;
        else
            wake();
        // Everything else is for the text field.
        event.accepted = escape || clearLine || wakingSpace;
    }

    // Qt does not report the state of Caps Lock, so it is read off what is
    // typed: a capital without Shift (or a small letter with it) means "on".
    // The key itself flips what is known so far.
    function noteCapsLock(event) {
        if (event.key === Qt.Key_CapsLock) {
            capsLock = !capsLock;
            return;
        }
        const typed = event.text;
        if (typed.length !== 1 || typed.toUpperCase() === typed.toLowerCase())
            return;
        const shift = (event.modifiers & Qt.ShiftModifier) !== 0;
        capsLock = (typed === typed.toUpperCase()) !== shift;
    }

    Scenery {
        anchors.fill: parent
        alert: root.auth.failure !== ""
        lively: root.prompting
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            power.open = false;
            root.wake();
        }
    }

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    // Back to the clock when the prompt is left alone.
    Timer {
        id: doze

        interval: 15000
        running: root.awake && root.auth.password === "" && !root.auth.checking
        onTriggered: {
            root.auth.reset();
            root.awake = false;
        }
    }

    Connections {
        target: root.auth

        function onRejected() {
            prompt.shake();
        }

        function onPasswordChanged() {
            if (field.text !== root.auth.password)
                field.text = root.auth.password;
        }
    }

    // Holds the keyboard focus and the text; the prompt's pill draws it.
    TextInput {
        id: field

        width: 1
        height: 1
        opacity: 0
        focus: true
        echoMode: TextInput.Password
        inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
        readOnly: root.auth.checking
        onTextEdited: root.auth.password = text
        onAccepted: root.auth.submit()
        Keys.onPressed: event => root.keyPressed(event)
    }

    // Everything but the backdrop arrives when the intro is over.
    Item {
        anchors.fill: parent
        opacity: intro.done ? 1 : 0
        transform: Translate {
            y: intro.done ? 0 : Theme.px(30)

            Behavior on y {
                NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic }
            }
        }

        Behavior on opacity {
            NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic }
        }

        Turn {
            shown: !root.prompting
            away: -120

            Column {
                anchors.centerIn: parent
                spacing: -Theme.px(10)

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter

                    Txt {
                        text: Qt.formatTime(clock.date, "HH")
                        size: 140
                        bold: true
                    }

                    Txt {
                        text: ":"
                        size: 140
                        bold: true
                        color: Theme.blue
                        opacity: 0.7
                    }

                    Txt {
                        text: Qt.formatTime(clock.date, "mm")
                        size: 140
                        bold: true
                    }
                }

                Txt {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDate(clock.date, "dddd, MMMM d")
                    size: 22
                    bold: true
                }
            }
        }

        Turn {
            shown: root.prompting
            away: 40

            Prompt {
                id: prompt

                anchors.centerIn: parent
                auth: root.auth
                capsLock: root.capsLock
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.px(40)
            spacing: Theme.px(16)

            // Keybinds do not work on a locked session, so this is also how
            // to get to the layout the password needs.
            Pill {
                visible: Daemon.hypr.layout !== ""
                icon: Icons.keyboard
                text: Daemon.hypr.layout
                interactive: true
                onClicked: Daemon.send("hypr.nextLayout")
            }

            Pill {
                readonly property var battery: Daemon.power.battery

                visible: battery.present
                icon: Icons.batteryLevel(battery.percent, battery.charging)
                text: Math.round(battery.percent) + "%"
                hue: battery.charging || battery.percent >= 60 ? Theme.green : battery.percent >= 25 ? Theme.yellow : Theme.red
                textColor: hue
            }

            Pill {
                readonly property var current: Daemon.weather.current

                visible: !!current
                icon: Icons.weather(current?.condition ?? "")
                text: Math.round(current?.temp ?? 0) + Daemon.weather.tempUnit
                hue: Theme.weatherColor(current?.condition ?? "")
            }

            MediaPill {}
        }

        PowerMenu {
            id: power

            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Theme.px(40)
            // Without the daemon there is nobody to carry the request out.
            visible: Daemon.connected
        }
    }

    Intro {
        id: intro

        anchors.fill: parent
    }
}
