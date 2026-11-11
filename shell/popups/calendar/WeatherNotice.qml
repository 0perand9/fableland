import QtQuick
import qs.core
import qs.widgets

// What the weather wing says when there is no forecast to show: still loading,
// the provider failed, or no location has been chosen yet.
Column {
    id: notice

    // `weather.status` and, when that is "error", what went wrong.
    property string status: "loading"
    property string error: ""

    readonly property bool loading: status === "loading"
    readonly property bool unconfigured: status === "unconfigured"

    spacing: Theme.px(12)

    Spinner {
        anchors.horizontalCenter: parent.horizontalCenter
        visible: notice.loading
        implicitWidth: Theme.px(40)
        implicitHeight: Theme.px(40)
    }

    Icon {
        anchors.horizontalCenter: parent.horizontalCenter
        visible: !notice.loading
        text: notice.unconfigured ? Icons.weatherPartlyDay : Icons.warning
        size: 48
        color: notice.unconfigured ? Theme.dim : Theme.yellow
    }

    Txt {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: notice.loading ? "Fetching the weather…" : notice.unconfigured ? "Weather is not set up" : "No weather right now"
        size: 16
        bold: true
    }

    Txt {
        width: parent.width
        visible: text !== ""
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        maximumLineCount: 4
        text: notice.loading ? "" : notice.unconfigured ? "Choose a location in Settings to see the forecast here." : (notice.error || "The forecast could not be loaded.")
        size: 12
        color: Theme.subtext
    }

    Btn {
        anchors.horizontalCenter: parent.horizontalCenter
        visible: !notice.loading
        kind: notice.unconfigured ? "filled" : "tonal"
        icon: notice.unconfigured ? Icons.settings : Icons.refresh
        text: notice.unconfigured ? "Open Settings" : "Try again"
        onClicked: {
            if (notice.unconfigured)
                Ui.open("settings", "weather");
            else
                Daemon.send("weather.refresh");
        }
    }
}
