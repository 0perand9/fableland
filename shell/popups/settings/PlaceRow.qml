import QtQuick
import qs.core
import qs.widgets

// The place the forecast is for: shows the chosen city, and finds another by
// name. Enter searches; a click chooses one of the places found, and so does
// Enter once the arrow keys are on one.
SettingRow {
    id: root

    readonly property string city: Daemon.setting("weather.city", "")
    readonly property var latitude: Daemon.setting("weather.lat", null)
    readonly property var longitude: Daemon.setting("weather.lon", null)
    // Places found by the last search: [{ name, region, country, lat, lon }].
    property var places: []
    property bool searching: false
    // The place the arrow keys are on, -1 while the field is for typing a name.
    property int selected: -1
    // Why there are no places to show, when a search came back without any.
    property string problem: ""

    function search(name) {
        if (name === "")
            return;
        searching = true;
        problem = "";
        Daemon.call("weather.geocode", { name: name }, (found, error) => {
            if (!root)
                return;
            searching = false;
            selected = -1;
            places = found ?? [];
            problem = error ? error : places.length === 0 ? "No place called “" + name + "” was found." : "";
        });
    }

    // City and coordinates belong together, so they are written in one go.
    function choose(place) {
        Daemon.send("settings.patch", { patch: { weather: { city: place.name, lat: place.lat, lon: place.lon } } });
        places = [];
        selected = -1;
        field.text = "";
    }

    // Reports whether there was a place to move to (otherwise the key is not for this row).
    function step(by) {
        const next = selected + by;
        if (next < -1 || next >= places.length)
            return false;
        selected = next;
        return true;
    }

    label: city !== "" ? city : "No city chosen"
    hint: typeof latitude === "number" && typeof longitude === "number" ? latitude.toFixed(2) + "°, " + longitude.toFixed(2) + "°" : "Search for a city to get a forecast"
    keywords: "weather.city weather.lat weather.lon location place latitude longitude"
    stacked: true
    onActivated: field.forceActiveFocus()

    Column {
        spacing: Theme.px(4)

        Field {
            id: field

            width: parent.width
            implicitHeight: Theme.px(34)
            size: 12
            icon: Icons.search
            placeholder: "Find a city, then press Enter"
            onAccepted: root.selected >= 0 ? root.choose(root.places[root.selected]) : root.search(text.trim())
            Keys.onDownPressed: event => event.accepted = root.step(1)
            Keys.onUpPressed: event => event.accepted = root.step(-1)

            Spinner {
                anchors.right: parent.right
                anchors.rightMargin: Theme.px(38)
                anchors.verticalCenter: parent.verticalCenter
                visible: root.searching
                implicitWidth: Theme.px(16)
                implicitHeight: Theme.px(16)
            }
        }

        Txt {
            visible: root.problem !== ""
            width: parent.width
            topPadding: Theme.px(4)
            text: root.problem
            size: 11
            color: Theme.yellow
            wrapMode: Text.WordWrap
            elide: Text.ElideNone
        }

        Repeater {
            model: root.places

            Clickable {
                id: place

                required property var modelData
                required property int index

                width: field.width
                height: Theme.px(40)
                fill: index === root.selected ? Theme.alpha(Theme.accent, 0.14) : "transparent"
                onClicked: root.choose(modelData)

                Icon {
                    id: pin

                    x: Theme.px(10)
                    anchors.verticalCenter: parent.verticalCenter
                    text: Icons.place
                    size: 15
                    color: Theme.dim
                }

                Column {
                    anchors.left: pin.right
                    anchors.right: parent.right
                    anchors.leftMargin: Theme.px(10)
                    anchors.rightMargin: Theme.px(10)
                    anchors.verticalCenter: parent.verticalCenter

                    Txt {
                        width: parent.width
                        text: place.modelData.name
                        size: 12
                    }

                    Txt {
                        width: parent.width
                        text: [place.modelData.region, place.modelData.country].filter(part => !!part).join(", ")
                        size: 11
                        color: Theme.dim
                    }
                }
            }
        }
    }
}
