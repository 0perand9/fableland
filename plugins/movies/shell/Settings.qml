import QtQuick
import qs.core
import qs.popups.settings

SettingsPage {
    Section {
        TextRow {
            path: "movies.openWith"
            label: "Open titles with"
            hint: "A link template. {title}, {id}, {type}, {season} and {episode} are filled in."
            keywords: "url link stream watch"
            icon: Icons.link
        }
    }
}
