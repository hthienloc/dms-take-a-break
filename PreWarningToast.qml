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

    anchors {
        bottom: true
        right: true
    }

    margins {
        bottom: Theme.spacingL + 48 // Account for standard bar height
        right: Theme.spacingL
    }

    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore

    StyledRect {
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHighest
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
