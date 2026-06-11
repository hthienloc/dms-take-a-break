import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import qs.Services

PluginComponent {
    id: pluginRoot

    property int shortBreakInterval: pluginData.shortBreakInterval ?? 20 // minutes
    property int shortBreakDuration: pluginData.shortBreakDuration ?? 20 // seconds
    property int shortBreaksBeforeLong: pluginData.shortBreaksBeforeLong ?? 3 // count
    property int longBreakDuration: pluginData.longBreakDuration ?? 5 // minutes

    property int preWarningTime: pluginData.preWarningTime ?? 10 // seconds
    property real preWarningOpacity: (pluginData.preWarningOpacity ?? 100) / 100

    property int completedShortBreaks: 0
    property bool suppressFullscreen: pluginData.suppressFullscreen ?? true
    property bool suppressMeetings: pluginData.suppressMeetings ?? true

    readonly property bool isDaemonInstance: pluginRoot.parent !== null

    property int nextBreakType: 0 // 0 for none, 1 for short, 2 for long
    property int timeToNextBreak: 0 // seconds
    property int breakTimeRemaining: 0 // seconds

    property bool isPreWarning: false
    property bool isBreakActive: false
    property bool isPaused: false

    pluginId: "takeABreak"
    pluginService: PluginService

    IpcHandler {
        target: "takeABreak"
        
        function preview(type: string): string {
            if (type === "prewarning") {
                if (pluginRoot.isPreWarning && preWarningWindow && preWarningWindow.visible) {
                    pluginRoot.isPreWarning = false;
                    preWarningWindow.visible = false;
                    return "Hiding pre-warning preview";
                }
                pluginRoot.isPreWarning = true;
                pluginRoot.showPreWarning();
                return "Showing pre-warning preview";
            } else if (type === "overlay") {
                if (pluginRoot.isBreakActive && overlayWindow && overlayWindow.visible) {
                    pluginRoot.isBreakActive = false;
                    pluginRoot.closeBreakOverlay();
                    return "Hiding overlay preview";
                }
                pluginRoot.isBreakActive = true;
                pluginRoot.showBreakOverlay();
                return "Showing overlay preview";
            }
            return "Usage: preview prewarning|overlay";
        }
    }

    // Timers
    Timer {
        id: sessionTimer
        interval: 1000
        repeat: true
        running: isDaemonInstance && !pluginRoot.isBreakActive && !pluginRoot.isPaused
        onTriggered: {
            pluginRoot.timeToNextBreak -= 1;
            
            if (pluginRoot.timeToNextBreak == pluginRoot.preWarningTime && !pluginRoot.isPreWarning) {
                // Show pre-warning X seconds before
                if (shouldSuppress()) {
                    // Snooze for 5 minutes
                    pluginRoot.timeToNextBreak += 300;
                    return;
                }
                pluginRoot.isPreWarning = true;
                showPreWarning();
            }

            if (pluginRoot.timeToNextBreak <= 0) {
                pluginRoot.isPreWarning = false;
                startBreak();
            }
        }
    }

    Timer {
        id: breakTimer
        interval: 1000
        repeat: true
        running: pluginRoot.isBreakActive
        onTriggered: {
            pluginRoot.breakTimeRemaining -= 1;
            if (pluginRoot.breakTimeRemaining <= 0) {
                endBreak();
            }
        }
    }

    function shouldSuppress() {
        if (pluginRoot.suppressFullscreen) {
            const screens = Quickshell.screens || [];
            for (let i = 0; i < screens.length; i++) {
                if (CompositorService.hasFullscreenToplevelOnScreen(screens[i].name)) {
                    return true;
                }
            }
        }

        if (pluginRoot.suppressMeetings && PrivacyService.microphoneActive) {
            return true;
        }

        return false;
    }

    Connections {
        target: PrivacyService
        function onMicrophoneActiveChanged() {
            if (PrivacyService.microphoneActive && pluginRoot.suppressMeetings) {
                if (pluginRoot.isPreWarning || pluginRoot.isBreakActive) {
                    pluginRoot.snoozeBreak();
                }
            }
        }
    }

    function resetSession() {
        pluginRoot.completedShortBreaks = 0;
        pluginRoot.nextBreakType = 1; // Start with short break
        pluginRoot.timeToNextBreak = pluginRoot.shortBreakInterval * 60;
        sessionTimer.restart();
    }

    function startBreak() {
        pluginRoot.isBreakActive = true;
        if (pluginRoot.nextBreakType === 1) {
            pluginRoot.breakTimeRemaining = pluginRoot.shortBreakDuration;
        } else {
            pluginRoot.breakTimeRemaining = pluginRoot.longBreakDuration * 60;
        }
        showBreakOverlay();
    }

    function endBreak() {
        pluginRoot.isBreakActive = false;
        closeBreakOverlay();
        
        if (pluginRoot.nextBreakType === 1) {
            pluginRoot.completedShortBreaks++;
        } else {
            pluginRoot.completedShortBreaks = 0;
        }

        if (pluginRoot.completedShortBreaks >= pluginRoot.shortBreaksBeforeLong) {
            pluginRoot.nextBreakType = 2;
        } else {
            pluginRoot.nextBreakType = 1;
        }
        
        pluginRoot.timeToNextBreak = pluginRoot.shortBreakInterval * 60;
    }

    function skipBreak() {
        if (pluginRoot.isPreWarning || (preWarningWindow && preWarningWindow.visible)) {
            pluginRoot.isPreWarning = false;
            if (preWarningWindow) preWarningWindow.visible = false;
            pluginRoot.timeToNextBreak = pluginRoot.shortBreakInterval * 60; // reset
        } else if (pluginRoot.isBreakActive || (overlayWindow && overlayWindow.visible)) {
            endBreak();
        }
    }

    function snoozeBreak() {
        if (pluginRoot.isPreWarning || (preWarningWindow && preWarningWindow.visible)) {
            pluginRoot.isPreWarning = false;
            if (preWarningWindow) preWarningWindow.visible = false;
        } else if (pluginRoot.isBreakActive || (overlayWindow && overlayWindow.visible)) {
            pluginRoot.isBreakActive = false;
            closeBreakOverlay();
        }
        pluginRoot.timeToNextBreak = 300; // 5 minutes snooze
        sessionTimer.restart();
    }

    // Dynamic component creation for Modals/Windows to keep widget small
    property var preWarningWindow: null
    property var overlayWindow: null

    function showPreWarning() {
        if (!preWarningWindow) {
            var comp = Qt.createComponent("PreWarningToast.qml");
            if (comp.status === Component.Ready) {
                preWarningWindow = comp.createObject(pluginRoot, { "pluginRoot": pluginRoot });
            }
        }
        if (preWarningWindow) preWarningWindow.visible = true;
    }

    function showBreakOverlay() {
        if (preWarningWindow) preWarningWindow.visible = false;
        
        if (!overlayWindow) {
            var comp = Qt.createComponent("TakeABreakOverlay.qml");
            if (comp.status === Component.Ready) {
                overlayWindow = comp.createObject(pluginRoot, { "pluginRoot": pluginRoot });
            }
        }
        if (overlayWindow) overlayWindow.visible = true;
    }

    function closeBreakOverlay() {
        if (overlayWindow) overlayWindow.visible = false;
    }

    onPluginIdChanged: {
        if (isDaemonInstance && pluginId !== "") {
            PluginService.setGlobalVar(pluginId, "instance", pluginRoot);
        }
    }

    Component.onCompleted: {
        if (isDaemonInstance) {
            if (pluginId !== "") {
                PluginService.setGlobalVar(pluginId, "instance", pluginRoot);
            }
            resetSession();
        }
    }

    popoutContent: Component {
        Column {
            width: 300
            spacing: Theme.spacingM
            padding: Theme.spacingM

            Row {
                width: parent.width
                spacing: Theme.spacingM

                DankIcon {
                    name: "self_improvement"
                    size: 32
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }

                Column {
                    width: parent.width - 32 - Theme.spacingM
                    spacing: 4

                    StyledText {
                        text: pluginRoot.isBreakActive ? I18n.tr("Currently on a break") : (pluginRoot.nextBreakType === 1 ? I18n.tr("Next: Short Break") : I18n.tr("Next: Long Break"))
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                    }

                    StyledText {
                        text: {
                            if (pluginRoot.isBreakActive) {
                                let m = Math.floor(pluginRoot.breakTimeRemaining / 60);
                                let s = pluginRoot.breakTimeRemaining % 60;
                                return (m > 0 ? m + ":" : "") + (s < 10 && m > 0 ? "0" : "") + s;
                            } else {
                                let m = Math.floor(pluginRoot.timeToNextBreak / 60);
                                let s = pluginRoot.timeToNextBreak % 60;
                                return `${m}:${s < 10 ? '0' : ''}${s}`;
                            }
                        }
                        font.pixelSize: Theme.fontSizeExtraLarge
                        font.weight: Font.Bold
                        color: pluginRoot.isPaused ? Theme.surfaceVariantText : Theme.surfaceText
                    }
                }
            }

            Item { width: 1; height: Theme.spacingS }

            Row {
                width: parent.width
                spacing: Theme.spacingS

                DankButton {
                    text: pluginRoot.isPaused ? I18n.tr("Resume") : I18n.tr("Pause")
                    iconName: pluginRoot.isPaused ? "play_arrow" : "pause"
                    backgroundColor: Theme.surfaceContainerHigh
                    textColor: Theme.surfaceText
                    width: (parent.width - parent.spacing) / 2
                    buttonHeight: 36
                    onClicked: pluginRoot.isPaused = !pluginRoot.isPaused
                }

                DankButton {
                    text: I18n.tr("Reset")
                    iconName: "refresh"
                    backgroundColor: Theme.surfaceContainerHigh
                    textColor: Theme.surfaceText
                    width: (parent.width - parent.spacing) / 2
                    buttonHeight: 36
                    onClicked: pluginRoot.resetSession()
                }
            }
        }
    }
}
