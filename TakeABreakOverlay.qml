import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Widgets

Item {
    id: rootOverlay
    property var pluginRoot

    property var tips: [
        I18n.tr("Look at something 20 feet away for 20 seconds."),
        I18n.tr("Blink 10-20 times quickly to moisten your eyes."),
        I18n.tr("Close your eyes tightly for 2 seconds, then open them."),
        I18n.tr("Roll your eyes clockwise, then counter-clockwise."),
        I18n.tr("Stretch your arms and neck."),
        I18n.tr("Drink a glass of water."),
        I18n.tr("Look out a window to relax your eye muscles.")
    ]

    property string currentTip: tips[0]

    Component.onCompleted: {
        currentTip = tips[Math.floor(Math.random() * tips.length)];
    }

    Repeater {
        model: Quickshell.screens

        delegate: PanelWindow {
            required property var modelData
            screen: modelData
            visible: rootOverlay.visible

            anchors {
                top: true; bottom: true; left: true; right: true
            }

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            exclusionMode: ExclusionMode.Ignore

            color: Theme.withAlpha(Theme.surface, (pluginRoot.pluginData.overlayOpacity ?? 100) / 100) // Dim background strongly

            Item {
                id: safeArea
                property int _refreshTrigger: 0
                anchors.fill: parent
                anchors.topMargin: { safeArea._refreshTrigger; return getOffset("top"); }
                anchors.bottomMargin: { safeArea._refreshTrigger; return getOffset("bottom"); }
                anchors.leftMargin: { safeArea._refreshTrigger; return getOffset("left"); }
                anchors.rightMargin: { safeArea._refreshTrigger; return getOffset("right"); }

                Column {
                    anchors.centerIn: parent
                    spacing: Theme.spacingL

                    DankIcon {
                        name: "self_improvement"
                        size: 80
                        color: Theme.primary
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    StyledText {
                        text: pluginRoot.nextBreakType === 1 ? I18n.tr("Short Break") : I18n.tr("Long Break")
                        font.pixelSize: Theme.fontSizeExtraLarge * 2
                        font.weight: Font.Bold
                        color: Theme.surfaceText
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    StyledText {
                        text: {
                            let m = Math.floor(pluginRoot.breakTimeRemaining / 60);
                            let s = pluginRoot.breakTimeRemaining % 60;
                            return (m > 0 ? m + ":" : "") + (s < 10 && m > 0 ? "0" : "") + s;
                        }
                        font.pixelSize: 120
                        font.weight: Font.Bold
                        color: Theme.primary
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    StyledText {
                        text: rootOverlay.currentTip
                        font.pixelSize: Theme.fontSizeLarge
                        color: Theme.surfaceVariantText
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }

                // Subtle skip button at bottom of safe area
                MouseArea {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottomMargin: Theme.spacingXL
                    width: skipText.width + 40
                    height: skipText.height + 40
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true

                    onClicked: pluginRoot.skipBreak()

                    StyledText {
                        id: skipText
                        anchors.centerIn: parent
                        text: I18n.tr("Skip this break")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        opacity: parent.containsMouse ? 0.6 : 0.2
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }
                }
            }

            function getOffset(edge) {
                if (typeof SettingsData === "undefined") return 0;
                let offset = 0;
                if (SettingsData.barConfigs) {
                    SettingsData.barConfigs.forEach(cfg => {
                        if (!cfg.enabled || !cfg.visible) return;
                        let onThisScreen = (!cfg.screenPreferences || cfg.screenPreferences.includes("all")) ? true : cfg.screenPreferences.includes(modelData.name);
                        if (!onThisScreen) return;
                        let edgeMatch = (edge === "top" && cfg.position === 0) || (edge === "bottom" && cfg.position === 1) || (edge === "left" && cfg.position === 2) || (edge === "right" && cfg.position === 3);
                        if (edgeMatch) {
                            let thickness = SettingsData.frameEnabled ? SettingsData.frameBarSize : Math.max(20, 26 + (cfg.innerPadding ?? 4) * 0.6) + (cfg.innerPadding ?? 4) + 4 + (cfg.spacing ?? 4) + ((typeof Theme !== "undefined" && Theme.isConnectedEffect) ? 0 : (cfg.bottomGap ?? 0));
                            offset = Math.max(offset, thickness);
                        }
                    });
                }
                if (SettingsData.dockEnabled && modelData === Quickshell.screens[0]) {
                    let edgeMatch = (edge === "top" && SettingsData.dockPosition === 0) || (edge === "bottom" && SettingsData.dockPosition === 1) || (edge === "left" && SettingsData.dockPosition === 2) || (edge === "right" && SettingsData.dockPosition === 3);
                    if (edgeMatch) {
                        let thickness = (SettingsData.dockIconSize ?? 40) + (SettingsData.dockSpacing ?? 4) * 2 + (SettingsData.dockBorderEnabled ? (SettingsData.dockBorderThickness ?? 1) : 0) * 2 + (SettingsData.dockBottomGap ?? 0) + ((typeof Theme !== "undefined" && Theme.isConnectedEffect) ? 0 : (SettingsData.dockMargin ?? 0)) + 8;
                        offset = Math.max(offset, thickness);
                    }
                }
                return offset;
            }

            Connections {
                target: (typeof SettingsData !== "undefined") ? SettingsData : null
                ignoreUnknownSignals: true
                function onBarConfigsChanged() { safeArea._refreshTrigger++; }
                function onDockEnabledChanged() { safeArea._refreshTrigger++; }
                function onDockPositionChanged() { safeArea._refreshTrigger++; }
            }
        }
    }
}
