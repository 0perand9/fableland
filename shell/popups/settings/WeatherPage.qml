import QtQuick
import qs.core
import qs.widgets

SettingsPage {
    id: page

    readonly property var weather: Daemon.weather
    readonly property bool ok: weather.status === "ok"
    readonly property bool openWeatherMap: Daemon.setting("weather.provider", "open-meteo") === "openweathermap"

    Section {
        // What the settings below currently lead to.
        ActionRow {
            label: page.ok ? page.weather.city + (page.weather.current ? " · " + Math.round(page.weather.current.temp) + page.weather.tempUnit : "") : page.weather.status === "unconfigured" ? "Not set up yet" : page.weather.status === "error" ? "The forecast could not be fetched" : "Fetching the forecast…"
            hint: page.ok ? (page.weather.current ? page.weather.current.desc + ", from " : "From ") + (page.weather.provider === "openweathermap" ? "OpenWeatherMap" : "Open-Meteo") : page.weather.error ?? ""
            keywords: "weather forecast status refresh"
            button: "Refresh"
            icon: Icons.refresh
            onTriggered: Daemon.send("weather.refresh")
        }
    }

    Section {
        title: "Source"

        ChoiceRow {
            path: "weather.provider"
            label: "Provider"
            hint: "Open-Meteo needs no account; OpenWeatherMap needs an API key"
            stacked: true
            options: [{ value: "open-meteo", label: "Open-Meteo" }, { value: "openweathermap", label: "OpenWeatherMap" }]
        }

        ChoiceRow {
            path: "weather.unit"
            label: "Units"
            hint: Daemon.setting("weather.unit", "metric") === "imperial" ? "°F and mph" : "°C and m/s"
            keywords: "celsius fahrenheit temperature"
            options: ["metric", "imperial"]
        }
    }

    Section {
        title: "Location"

        PlaceRow {
            available: !page.openWeatherMap
        }
    }

    Section {
        title: "OpenWeatherMap"

        TextRow {
            path: "weather.owmKey"
            label: "API key"
            hint: "A new key can take a few hours to start working"
            keywords: "openweathermap secret token"
            available: page.openWeatherMap
            secret: true
            icon: Icons.key
            placeholder: "Paste the key"
        }

        TextRow {
            path: "weather.owmCityId"
            label: "City id"
            hint: "The number at the end of the city's address on openweathermap.org"
            keywords: "openweathermap location place"
            available: page.openWeatherMap
            placeholder: "Like 2624652"
        }

        ActionRow {
            label: "Get an API key"
            hint: "A free account is enough"
            keywords: "openweathermap website"
            available: page.openWeatherMap
            button: "Open"
            icon: Icons.openExternal
            onTriggered: Daemon.send("misc.open", { target: "https://home.openweathermap.org/api_keys" })
        }

        ActionRow {
            label: "Find your city"
            hint: "Search for it, open it, and copy the id"
            keywords: "openweathermap website city id"
            available: page.openWeatherMap
            button: "Open"
            icon: Icons.openExternal
            onTriggered: Daemon.send("misc.open", { target: "https://openweathermap.org/find" })
        }
    }
}
