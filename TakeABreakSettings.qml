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

    Process {
        id: previewSoundProc
        command: ["dms", "ipc", "call", "takeABreak", "play_sound", "start"]
    }

    property var livePlugin: null

    Timer {
        interval: 1000
        running: livePlugin === null
        repeat: true
        onTriggered: livePlugin = PluginService.getGlobalVar("takeABreak", "instance")
    }

    Component.onCompleted: {
        livePlugin = PluginService.getGlobalVar("takeABreak", "instance");
        PluginService.globalVarChanged.connect((pid, vname) => {
            if (pid === "takeABreak" && vname === "instance") {
                livePlugin = PluginService.getGlobalVar("takeABreak", "instance");
            }
        });
    }

    SettingsCard {
        visible: livePlugin !== null
        
        StatusDisplay {
            large: true
            iconName: livePlugin ? (livePlugin.isPaused ? "pause_circle" : "timer") : ""
            title: {
                if (!livePlugin) return "";
                if (livePlugin.isPaused) return I18n.tr("Paused");
                if (livePlugin.isBreakActive) return livePlugin.nextBreakType === 1 ? I18n.tr("Short Break Active") : I18n.tr("Long Break Active");
                return livePlugin.nextBreakType === 1 ? I18n.tr("Next: Short Break") : I18n.tr("Next: Long Break");
            }
            subtitle: {
                if (!livePlugin) return "0:00";
                let total = livePlugin.isBreakActive ? livePlugin.breakTimeRemaining : livePlugin.timeToNextBreak;
                let m = Math.floor(total / 60);
                let s = total % 60;
                return `${m}:${s < 10 ? '0' : ''}${s}`;
            }
            active: livePlugin ? livePlugin.isBreakActive : false
            progress: {
                if (!livePlugin) return -1;
                if (livePlugin.isBreakActive) {
                    let duration = livePlugin.nextBreakType === 1 ? livePlugin.shortBreakDuration : livePlugin.longBreakDuration * 60;
                    return livePlugin.breakTimeRemaining / duration;
                } else {
                    let interval = livePlugin.nextBreakType === 1 ? livePlugin.shortBreakInterval * 60 : livePlugin.longBreakInterval * 60;
                    return 1 - (livePlugin.timeToNextBreak / interval);
                }
            }
        }

        Item { width: 1; height: Theme.spacingS }

        Row {
            width: parent.width - Theme.spacingM * 2
            x: Theme.spacingM
            spacing: Theme.spacingS

            DankButton {
                text: livePlugin && livePlugin.isPaused ? I18n.tr("Resume") : I18n.tr("Pause")
                iconName: livePlugin && livePlugin.isPaused ? "play_arrow" : "pause"
                backgroundColor: Theme.surfaceContainerHigh
                textColor: Theme.surfaceText
                width: (parent.width - parent.spacing) / 2
                buttonHeight: 36
                onClicked: if (livePlugin) livePlugin.isPaused = !livePlugin.isPaused
            }

            DankButton {
                text: I18n.tr("Reset Session")
                iconName: "refresh"
                backgroundColor: Theme.surfaceContainerHigh
                textColor: Theme.surfaceText
                width: (parent.width - parent.spacing) / 2
                buttonHeight: 36
                onClicked: if (livePlugin) livePlugin.resetSession()
            }
        }
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
            defaultValue: 20
            minimum: 5
            maximum: 120
            unit: "s"
            leftLabel: "5s"
            rightLabel: "2m"
        }

        SettingsDivider {}

        SliderSettingPlus {
            settingKey: "shortBreaksBeforeLong"
            label: I18n.tr("Short breaks before long break")
            defaultValue: 3
            minimum: 1
            maximum: 10
            unit: ""
            leftLabel: "1"
            rightLabel: "10"
        }

        SliderSettingPlus {
            id: longBreakDuration
            settingKey: "longBreakDuration"
            label: I18n.tr("Long Break Duration")
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
            text: I18n.tr("Break Timing")
            icon: "schedule"
        }

        SliderSettingPlus {
            settingKey: "preWarningTime"
            label: I18n.tr("Pre-break Warning Timing")
            description: I18n.tr("How many seconds before the break to show the warning notification.")
            defaultValue: 5
            minimum: 0
            maximum: 15
            unit: "s"
            leftLabel: "0s"
            rightLabel: "15s"
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
            text: I18n.tr("Sound Alerts")
            icon: "volume_up"
        }

        ToggleSettingPlus {
            settingKey: "soundEnabled"
            label: I18n.tr("Enable Sound Alerts")
            description: I18n.tr("Play a gentle sound when a break starts and ends.")
            defaultValue: true
        }

        SettingsDivider {}

        SliderSettingPlus {
            settingKey: "soundVolume"
            label: I18n.tr("Alert Volume")
            defaultValue: 80
            minimum: 0
            maximum: 100
            unit: "%"
            leftLabel: "0%"
            rightLabel: "100%"
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
            settingKey: "preWarningOpacity"
            label: I18n.tr("Pre-warning Opacity")
            description: I18n.tr("How transparent the pre-warning notification should be.")
            defaultValue: 100
            minimum: 20
            maximum: 100
            unit: "%"
            leftLabel: "20%"
            rightLabel: "100%"
        }

        SettingsDivider {}

        SliderSettingPlus {
            settingKey: "overlayOpacity"
            label: I18n.tr("Overlay Background Opacity")
            description: I18n.tr("How transparent the fullscreen break background should be.")
            defaultValue: 100
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

        Column {
            width: parent.width - Theme.spacingM * 2
            x: Theme.spacingM
            spacing: Theme.spacingS

            Row {
                width: parent.width
                spacing: Theme.spacingS

                DankButton {
                    text: (livePlugin && livePlugin.isPreWarning) ? I18n.tr("Hide Pre-Warning") : I18n.tr("Preview Pre-Warning")
                    iconName: (livePlugin && livePlugin.isPreWarning) ? "notifications_off" : "notifications"
                    backgroundColor: (livePlugin && livePlugin.isPreWarning) ? Theme.primaryContainer : Theme.surfaceContainerHigh
                    textColor: (livePlugin && livePlugin.isPreWarning) ? Theme.primary : Theme.surfaceText
                    width: (parent.width - parent.spacing) / 2
                    buttonHeight: 36
                    onClicked: previewPreWarningProc.running = true
                }

                DankButton {
                    text: (livePlugin && livePlugin.isBreakActive) ? I18n.tr("Hide Overlay") : I18n.tr("Preview Fullscreen Break")
                    iconName: (livePlugin && livePlugin.isBreakActive) ? "fullscreen_exit" : "fullscreen"
                    backgroundColor: (livePlugin && livePlugin.isBreakActive) ? Theme.primaryContainer : Theme.surfaceContainerHigh
                    textColor: (livePlugin && livePlugin.isBreakActive) ? Theme.primary : Theme.surfaceText
                    width: (parent.width - parent.spacing) / 2
                    buttonHeight: 36
                    onClicked: previewOverlayProc.running = true
                }
            }

            DankButton {
                text: I18n.tr("Test Alert Sound")
                iconName: "volume_up"
                backgroundColor: Theme.surfaceContainerHigh
                textColor: Theme.surfaceText
                width: parent.width
                buttonHeight: 36
                onClicked: previewSoundProc.running = true
            }
        }
    }

    PluginAbout {
        repoUrl: "https://github.com/hthienloc/dms-take-a-break"
    }
}
