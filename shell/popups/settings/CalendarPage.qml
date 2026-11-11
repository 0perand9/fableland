import QtQuick
import qs.core

SettingsPage {
    Section {
        title: "Diary"

        TextRow {
            path: "diary.dir"
            label: "Folder"
            hint: "One note per day, opened from the calendar"
            keywords: "directory path notes journal"
            directory: true
        }

        TextRow {
            path: "diary.obsidianVault"
            label: "Obsidian vault"
            hint: "Name of the vault that contains the folder: notes then open in Obsidian"
            keywords: "notes journal"
            placeholder: "None — notes open in the default editor"
        }
    }

    Section {
        title: "Schedule"

        TextRow {
            path: "schedule.command"
            label: "Command"
            hint: "Prints today's events as JSON for the calendar: { title, events: [{ title, start, end, where, note, date }] }"
            keywords: "classes timetable events script"
            placeholder: "None"
            icon: Icons.terminal
        }
    }
}
