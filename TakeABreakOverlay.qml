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

            anchors {
                top: true; bottom: true; left: true; right: true
            }

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            exclusionMode: ExclusionMode.Ignore

            color: Theme.withAlpha(Theme.surface, 0.90) // Dim background strongly

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

            // Subtle skip button at bottom
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
    }
}
