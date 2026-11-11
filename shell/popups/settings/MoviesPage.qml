import QtQuick
import qs.core

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
