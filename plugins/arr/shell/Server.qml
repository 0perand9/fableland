import QtQuick
import qs.core
import qs.popups.settings

// The settings of one server, Sonarr or Radarr, with a button that tries them.
Section {
    id: root

    required property string service      // "sonarr" or "radarr"
    required property string port         // its usual one, for the placeholder
    readonly property string name: service === "sonarr" ? "Sonarr" : "Radarr"
    // What the last test found.
    property string verdict: ""

    title: name

    TextRow {
        path: "arr." + root.service + ".url"
        label: "Address"
        hint: "Where " + root.name + " answers, with http:// or https://."
        placeholder: "http://localhost:" + root.port
        fieldWidth: Theme.px(190)
        icon: Icons.link
        keywords: "url server host arr"
    }

    TextRow {
        path: "arr." + root.service + ".apiKey"
        label: "API key"
        hint: "Settings › General in " + root.name + "."
        secret: true
        fieldWidth: Theme.px(190)
        keywords: "token password arr"
    }

    TextRow {
        path: "arr." + root.service + ".apiKeyFile"
        label: "API key file"
        hint: "Or a file that holds the key, which keeps it out of settings.json (and the Nix store). Used when set."
        placeholder: "~/.secrets/" + root.service
        fieldWidth: Theme.px(190)
        keywords: "token secret sops agenix arr"
    }

    TextRow {
        path: "arr." + root.service + ".qualityProfile"
        label: "Quality profile"
        hint: "The name of the profile requests use. Empty: the first one."
        placeholder: "first"
        keywords: "quality arr"
    }

    TextRow {
        path: "arr." + root.service + ".rootFolder"
        label: "Root folder"
        hint: "Where " + root.name + " puts what is requested. Empty: its first root folder."
        placeholder: "first"
        fieldWidth: Theme.px(190)
        keywords: "path library arr"
    }

    ActionRow {
        label: "Try it"
        hint: root.verdict !== "" ? root.verdict : "Asks " + root.name + " whether these settings work."
        button: "Test"
        icon: Icons.check
        onTriggered: {
            root.verdict = "Asking…";
            Daemon.call("arr.test", { service: root.service }, (result, error) => {
                root.verdict = error ? "Failed: " + error : root.name + " " + result.version + " answers. Requests go to " + result.rootFolder + " as " + result.profile + ".";
            });
        }
    }
}
