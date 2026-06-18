import QtQuick
import QtMultimedia
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

    property int preWarningTime: pluginData.preWarningTime ?? 5 // seconds
    property real preWarningOpacity: (pluginData.preWarningOpacity ?? 100) / 100

    property bool soundEnabled: pluginData.soundEnabled ?? true
    property real soundVolume: (pluginData.soundVolume ?? 80) / 100

    property int completedShortBreaks: 0
    property bool suppressFullscreen: pluginData.suppressFullscreen ?? true
    property bool suppressMeetings: pluginData.suppressMeetings ?? true

    readonly property bool isDaemonInstance: pluginRoot.parent !== null

    property int nextBreakType: 0 // 0 for none, 1 for short, 2 for long
    property int timeToNextBreak: 0 // seconds
    property int breakTimeRemaining: 0 // seconds

    property bool isPreWarning: false
    property bool isBreakActive: false
    property bool isPaused: pluginData.isPaused ?? false

    pluginId: "takeABreak"
    pluginService: PluginService

    // ── Statistics ──────────────────────────────────────────────────────────
    readonly property string statsFilePath: {
        var home = Quickshell.env("HOME");
        return home + "/.local/share/dms-take-a-break/stats.json";
    }

    function logEvent(status) {
        var file = statsFilePath;
        Proc.runCommand("takeABreak.readStats", ["sh", "-c",
            "cat \"" + file + "\" 2>/dev/null || echo '{\"events\":[]}'"
        ], (stdout) => {
            var stats = JSON.parse(stdout);
            var type = pluginRoot.nextBreakType === 1 ? "short" : "long";
            var ts = Math.floor(Date.now() / 1000);
            stats.events.push({ ts: ts, type: type, status: status });
            var json = JSON.stringify(stats);
            var escaped = json.replace(/\"/g, '\\"');
            Proc.runCommand("takeABreak.writeStats", ["sh", "-c",
                "mkdir -p \"$(dirname \"" + file + "\")\" && printf '%s' \"" + escaped + "\" > \"" + file + "\""
            ]);
        });
    }

    function getStats() {
        var file = statsFilePath;
        Proc.runCommand("takeABreak.readStats", ["sh", "-c",
            "cat \"" + file + "\" 2>/dev/null || echo '{\"events\":[]}'"
        ], (stdout) => {
            try {
                var stats = JSON.parse(stdout);
                var now = new Date();
                var todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime() / 1000;
                var weekStart = todayStart - 6 * 86400;
                var todayTotal = 0, todayCompleted = 0, todaySkipped = 0, todaySnoozed = 0;
                var weekTotal = 0, weekCompleted = 0, weekSkipped = 0, weekSnoozed = 0;
                for (var i = 0; i < stats.events.length; i++) {
                    var e = stats.events[i];
                    if (e.ts >= todayStart) {
                        todayTotal++;
                        if (e.status === "completed") todayCompleted++;
                        else if (e.status === "skipped") todaySkipped++;
                        else if (e.status === "snoozed") todaySnoozed++;
                    }
                    if (e.ts >= weekStart) {
                        weekTotal++;
                        if (e.status === "completed") weekCompleted++;
                        else if (e.status === "skipped") weekSkipped++;
                        else if (e.status === "snoozed") weekSnoozed++;
                    }
                }
                var todayResponded = todayCompleted + todaySkipped + todaySnoozed;
                var weekResponded = weekCompleted + weekSkipped + weekSnoozed;
                pluginRoot._stats = {
                    todayRate: todayResponded > 0 ? Math.round(todayCompleted / todayResponded * 100) : -1,
                    todayCompleted: todayCompleted,
                    todaySkipped: todaySkipped,
                    todaySnoozed: todaySnoozed,
                    todayTotal: todayTotal,
                    weekRate: weekResponded > 0 ? Math.round(weekCompleted / weekResponded * 100) : -1,
                    weekCompleted: weekCompleted,
                    weekSkipped: weekSkipped,
                    weekSnoozed: weekSnoozed,
                    weekTotal: weekTotal,
                    totalAll: stats.events.length
                };
                if (typeof _onStatsReady === "function") _onStatsReady();
            } catch (e) {
                console.warn("[TakeABreak] Failed to parse stats:", e);
            }
        });
    }
    property var _stats: null
    property var _onStatsReady: null

    readonly property var masterInstance: (isDaemonInstance) ? pluginRoot : PluginService.getGlobalVar(pluginId, "instance")

    // Control Center Integration
    ccWidgetIcon: "self_improvement"
    ccWidgetPrimaryText: I18n.tr("Take a Break")
    ccWidgetSecondaryText: {
        const master = pluginRoot.masterInstance;
        if (!master) return "";
        if (master.isPaused) return I18n.tr("Paused");
        
        let total = master.isBreakActive ? master.breakTimeRemaining : master.timeToNextBreak;
        let m = Math.floor(total / 60);
        let s = total % 60;
        let timeStr = `${m}:${s < 10 ? '0' : ''}${s}`;
        
        return master.isBreakActive ? I18n.tr("Active: ") + timeStr : timeStr;
    }
    ccWidgetIsActive: masterInstance ? !masterInstance.isPaused : true
    onCcWidgetToggled: {
        const master = pluginRoot.masterInstance;
        if (master) {
            master.isPaused = !master.isPaused;
            pluginService?.savePluginData(pluginId, "isPaused", master.isPaused);
        }
    }

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

        function play_sound(type: string): string {
            pluginRoot.playSound(type || "start");
            return "Playing sound: " + (type || "start");
        }
    }

    // Audio
    MediaPlayer {
        id: alertPlayer
        audioOutput: AudioOutput {
            volume: pluginRoot.soundVolume
        }
    }

    function playSound(type) {
        if (!pluginRoot.soundEnabled) return;
        if (typeof AudioService === "undefined" || !AudioService || !AudioService.soundsAvailable) return;
        
        alertPlayer.stop();
        if (type === "start") {
            alertPlayer.source = AudioService.getSoundPath("message");
        } else {
            alertPlayer.source = AudioService.getSoundPath("audio-volume-change");
        }
        alertPlayer.play();
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
        playSound("start");
    }

    function endBreak() {
        pluginRoot.isBreakActive = false;
        closeBreakOverlay();
        playSound("end");
        pluginRoot.logEvent("completed");
        
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
            pluginRoot.logEvent("skipped");
            pluginRoot.isPreWarning = false;
            if (preWarningWindow) preWarningWindow.visible = false;
            pluginRoot.timeToNextBreak = pluginRoot.shortBreakInterval * 60;
        } else if (pluginRoot.isBreakActive || (overlayWindow && overlayWindow.visible)) {
            pluginRoot.logEvent("skipped");
            pluginRoot.isBreakActive = false;
            closeBreakOverlay();
            pluginRoot.completedShortBreaks = pluginRoot.nextBreakType === 1 ? pluginRoot.completedShortBreaks + 1 : 0;
            if (pluginRoot.completedShortBreaks >= pluginRoot.shortBreaksBeforeLong) {
                pluginRoot.nextBreakType = 2;
            } else {
                pluginRoot.nextBreakType = 1;
            }
            pluginRoot.timeToNextBreak = pluginRoot.shortBreakInterval * 60;
        }
    }

    function snoozeBreak() {
        pluginRoot.logEvent("snoozed");
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
