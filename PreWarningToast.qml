import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Widgets

PanelWindow {
    id: root

    property var pluginRoot

    width: 320
    height: 140
    color: "transparent"

    screen: Quickshell.primaryScreen

    property string alignment: pluginRoot.pluginData.preWarningAlignment ?? "bottom-right"

    anchors {
        top: alignment.includes("top")
        bottom: alignment.includes("bottom")
        left: alignment.includes("left")
        right: alignment.includes("right")
    }

    property int _refreshTrigger: 0

    WlrLayershell.margins {
        top: {
            root._refreshTrigger;
            let m = alignment.includes("top") ? Theme.spacingL : 0;
            if (alignment.includes("top")) m += getOffset("top");
            return m;
        }
        bottom: {
            root._refreshTrigger;
            let m = alignment.includes("bottom") ? Theme.spacingL : 0;
            if (alignment.includes("bottom")) m += getOffset("bottom");
            return m;
        }
        left: {
            root._refreshTrigger;
            let m = alignment.includes("left") ? Theme.spacingL : 0;
            if (alignment.includes("left")) m += getOffset("left");
            return m;
        }
        right: {
            root._refreshTrigger;
            let m = alignment.includes("right") ? Theme.spacingL : 0;
            if (alignment.includes("right")) m += getOffset("right");
            return m;
        }
    }

    function getOffset(edge) {
        if (typeof SettingsData === "undefined") return 0;
        let offset = 0;

        // Bars
        if (SettingsData.barConfigs) {
            SettingsData.barConfigs.forEach(cfg => {
                if (!cfg.enabled || !cfg.visible) return;
                
                let onThisScreen = false;
                if (!cfg.screenPreferences || cfg.screenPreferences.includes("all")) onThisScreen = true;
                else onThisScreen = cfg.screenPreferences.includes(root.screen.name);
                
                if (!onThisScreen) return;

                // Position: 0=Top, 1=Bottom, 2=Left, 3=Right
                let edgeMatch = false;
                if (edge === "top" && cfg.position === 0) edgeMatch = true;
                else if (edge === "bottom" && cfg.position === 1) edgeMatch = true;
                else if (edge === "left" && cfg.position === 2) edgeMatch = true;
                else if (edge === "right" && cfg.position === 3) edgeMatch = true;

                if (edgeMatch) {
                    const innerPadding = cfg.innerPadding ?? 4;
                    const spacing = cfg.spacing ?? 4;
                    const bottomGap = (typeof Theme !== "undefined" && Theme.isConnectedEffect) ? 0 : (cfg.bottomGap ?? 0);
                    let thickness = 0;
                    if (SettingsData.frameEnabled) {
                        thickness = SettingsData.frameBarSize;
                    } else {
                        const widgetThickness = Math.max(20, 26 + innerPadding * 0.6);
                        const barHeight = typeof Theme !== "undefined" ? Theme.barHeight : 48;
                        const effectiveBarThickness = Math.max(widgetThickness + innerPadding + 4, barHeight - 4 - (8 - innerPadding));
                        thickness = effectiveBarThickness + spacing + bottomGap;
                    }
                    offset = Math.max(offset, thickness);
                }
            });
        }

        // Dock
        if (SettingsData.dockEnabled && root.screen === Quickshell.screens[0]) {
            let edgeMatch = false;
            // Dock Position: 0=Top, 1=Bottom, 2=Left, 3=Right
            if (edge === "top" && SettingsData.dockPosition === 0) edgeMatch = true;
            else if (edge === "bottom" && SettingsData.dockPosition === 1) edgeMatch = true;
            else if (edge === "left" && SettingsData.dockPosition === 2) edgeMatch = true;
            else if (edge === "right" && SettingsData.dockPosition === 3) edgeMatch = true;

            if (edgeMatch) {
                const iconSize = SettingsData.dockIconSize ?? 40;
                const spacing = SettingsData.dockSpacing ?? 4;
                const borderThickness = SettingsData.dockBorderEnabled ? (SettingsData.dockBorderThickness ?? 1) : 0;
                const bodyThickness = iconSize + spacing * 2 + borderThickness * 2;
                const reserveOffset = SettingsData.dockBottomGap ?? 0;
                const effectiveMargin = (typeof Theme !== "undefined" && Theme.isConnectedEffect) ? 0 : (SettingsData.dockMargin ?? 0);
                const dockThickness = bodyThickness + reserveOffset + effectiveMargin + 8;
                offset = Math.max(offset, dockThickness);
            }
        }

        return offset;
    }

    Connections {
        target: (typeof SettingsData !== "undefined") ? SettingsData : null
        ignoreUnknownSignals: true
        function onBarConfigsChanged() { root._refreshTrigger++; }
        function onDockEnabledChanged() { root._refreshTrigger++; }
        function onDockPositionChanged() { root._refreshTrigger++; }
    }

    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore

    StyledRect {
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHighest
        opacity: pluginRoot.preWarningOpacity
        border.color: Theme.outline
        border.width: 1

        Column {
            anchors.fill: parent
            anchors.margins: Theme.spacingM
            spacing: Theme.spacingS

            Row {
                spacing: Theme.spacingS
                DankIcon {
                    name: "hourglass_empty"
                    size: 24
                    color: Theme.primary
                }
                StyledText {
                    text: I18n.tr("Take a Break")
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.Bold
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            StyledText {
                text: I18n.tr("Your ") + (pluginRoot.nextBreakType === 1 ? I18n.tr("short") : I18n.tr("long")) + I18n.tr(" break starts in ") + pluginRoot.timeToNextBreak + "s."
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
                width: parent.width
            }

            Item { width: 1; height: Theme.spacingXS }

            Row {
                width: parent.width
                spacing: Theme.spacingS

                DankButton {
                    text: I18n.tr("Snooze (5m)")
                    iconName: "snooze"
                    backgroundColor: Theme.primaryContainer
                    textColor: Theme.primary
                    width: parent.width - skipBtn.width - parent.spacing
                    buttonHeight: 36
                    onClicked: pluginRoot.snoozeBreak()
                }

                MouseArea {
                    id: skipBtn
                    width: 60
                    height: 36
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: pluginRoot.skipBreak()

                    StyledText {
                        anchors.centerIn: parent
                        text: I18n.tr("Skip")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        opacity: parent.containsMouse ? 1.0 : 0.5
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }
                }
            }
        }
    }
}
