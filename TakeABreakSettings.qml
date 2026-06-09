pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import qs.Services

PluginSettings {
    id: rootSettings
    pluginId: "takeABreak"

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

    PluginAbout {
        repoUrl: "https://github.com/hthienloc/dms-take-a-break"
    }
}
