import QtQuick
import qs.core

SettingsPage {
    Section {
        title: "Screenshots and recordings"
        feature: "capture"

        TextRow {
            path: "capture.dir"
            label: "Screenshot folder"
            keywords: "directory path pictures"
            directory: true
        }

        TextRow {
            path: "capture.videoDir"
            label: "Recording folder"
            keywords: "directory path videos"
            directory: true
        }

        ChoiceRow {
            path: "capture.editor"
            label: "Editor"
            hint: "Opens a screenshot for annotating"
            keywords: "annotate"
            options: ["satty", "swappy"]
        }

        ChoiceRow {
            path: "capture.audio"
            label: "Record sound"
            keywords: "audio microphone"
            segmentWidth: 70
            options: [{ value: "none", label: "None" }, { value: "desktop", label: "Desktop" }, { value: "mic", label: "Mic" }]
        }
    }

    Section {
        title: "Clipboard"
        feature: "clipboard"

        ToggleRow {
            path: "clipboard.autoPaste"
            label: "Paste after picking"
            hint: "Picking an entry in the clipboard history also pastes it"
            keywords: "history"
        }
    }
}
