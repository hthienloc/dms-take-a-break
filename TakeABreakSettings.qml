pragma ComponentBehavior: Bound

import "./dms-common"
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import qs.Services

PluginSettings {
    id: rootSettings
    pluginId: "takeABreak"

    Process {
        id: previewPreWarningProc
        command: ["dms", "ipc", "call", "takeABreak", "preview", "prewarning"]
    }

    Process {
        id: previewOverlayProc
        command: ["dms", "ipc", "call", "takeABreak", "preview", "overlay"]
    }

    SettingsCard {
        SectionTitle {
            text: I18n.tr("Break Intervals")
            icon: "timer"
        }

        SliderSettingPlus {
            id: shortBreakInterval
            settingKey: "shortBreakInterval"
            label: I18n.tr("Short Break Interval")
            description: I18n.tr("Time between short breaks (20-20-20 rule).")
            defaultValue: 20
            minimum: 5
            maximum: 60
            unit: "m"
            leftLabel: "5m"
            rightLabel: "60m"
        }

        SliderSettingPlus {
            id: shortBreakDuration
            settingKey: "shortBreakDuration"
            label: I18n.tr("Short Break Duration")
            description: I18n.tr("How long a short break lasts.")
            defaultValue: 20
            minimum: 5
            maximum: 120
            unit: "s"
            leftLabel: "5s"
            rightLabel: "2m"
        }

        SettingsDivider {}

        SliderSettingPlus {
            id: longBreakInterval
            settingKey: "longBreakInterval"
            label: I18n.tr("Long Break Interval")
            description: I18n.tr("Time between long breaks.")
            defaultValue: 60
            minimum: 30
            maximum: 180
            unit: "m"
            leftLabel: "30m"
            rightLabel: "3h"
        }

        SliderSettingPlus {
            id: longBreakDuration
            settingKey: "longBreakDuration"
            label: I18n.tr("Long Break Duration")
            description: I18n.tr("How long a long break lasts.")
            defaultValue: 5
            minimum: 1
            maximum: 30
            unit: "m"
            leftLabel: "1m"
            rightLabel: "30m"
        }
    }

    SettingsCard {
        SectionTitle {
            text: I18n.tr("Smart Suppression")
            icon: "psychology"
        }

        ToggleSettingPlus {
            id: suppressFullscreen
            settingKey: "suppressFullscreen"
            label: I18n.tr("Suppress in Fullscreen")
            description: I18n.tr("Automatically snooze breaks if an application is running in fullscreen.")
            defaultValue: true
        }

        ToggleSettingPlus {
            id: suppressMeetings
            settingKey: "suppressMeetings"
            label: I18n.tr("Suppress during Meetings")
            description: I18n.tr("Automatically snooze breaks if your microphone is active.")
            defaultValue: true
        }
    }

    SettingsCard {
        SectionTitle {
            text: I18n.tr("UI Appearance")
            icon: "palette"
        }

        SelectionSettingPlus {
            settingKey: "preWarningAlignment"
            label: I18n.tr("Pre-warning Position")
            description: I18n.tr("Where the pre-warning notification appears.")
            options: [
                { label: I18n.tr("Top Left"), value: "top-left" },
                { label: I18n.tr("Top Center"), value: "top-center" },
                { label: I18n.tr("Top Right"), value: "top-right" },
                { label: I18n.tr("Bottom Left"), value: "bottom-left" },
                { label: I18n.tr("Bottom Center"), value: "bottom-center" },
                { label: I18n.tr("Bottom Right"), value: "bottom-right" },
                { label: I18n.tr("Left Center"), value: "left-center" },
                { label: I18n.tr("Right Center"), value: "right-center" }
            ]
            defaultValue: "bottom-right"
        }

        SettingsDivider {}

        SliderSettingPlus {
            settingKey: "overlayOpacity"
            label: I18n.tr("Overlay Background Opacity")
            description: I18n.tr("How transparent the fullscreen break background should be.")
            defaultValue: 90
            minimum: 50
            maximum: 100
            unit: "%"
            leftLabel: "50%"
            rightLabel: "100%"
        }
    }

    SettingsCard {
        SectionTitle {
            text: I18n.tr("Testing & Preview")
            icon: "preview"
        }

        Row {
            width: parent.width - Theme.spacingM * 2
            x: Theme.spacingM
            spacing: Theme.spacingS

            DankButton {
                text: I18n.tr("Preview Pre-Warning")
                iconName: "notifications"
                backgroundColor: Theme.surfaceContainerHigh
                textColor: Theme.surfaceText
                width: (parent.width - parent.spacing) / 2
                buttonHeight: 36
                onClicked: previewPreWarningProc.running = true
            }

            DankButton {
                text: I18n.tr("Preview Fullscreen Break")
                iconName: "fullscreen"
                backgroundColor: Theme.surfaceContainerHigh
                textColor: Theme.surfaceText
                width: (parent.width - parent.spacing) / 2
                buttonHeight: 36
                onClicked: previewOverlayProc.running = true
            }
        }
    }

    PluginAbout {
        repoUrl: "https://github.com/hthienloc/dms-take-a-break"
    }
}
