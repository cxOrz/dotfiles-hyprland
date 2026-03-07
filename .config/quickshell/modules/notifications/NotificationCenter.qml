import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../.." as Root

// Notification Center — right-side panel displaying dunst notification history
PanelWindow {
    id: notifCenter

    // Panel visibility state
    property bool panelVisible: false
    property bool _showing: false  // stays true during close animation

    // Fullscreen transparent overlay to capture outside clicks
    visible: _showing
    color: "transparent"

    // Anchor to right edge, full height
    anchors {
        top: true
        right: true
        bottom: true
        left: true
    }

    // No screen space reservation
    exclusionMode: ExclusionMode.Ignore
    focusable: true

    // WlrLayershell configuration
    WlrLayershell.namespace: "quickshell:notifications"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    // Auto-refresh when panel becomes visible
    onPanelVisibleChanged: {
        if (panelVisible) {
            _showing = true;
            NotificationService.refresh();
        }
        // When closing, _showing stays true until animation completes
    }

    // IPC Handler for external toggle via `qs ipc call notifications toggle`
    IpcHandler {
        target: "notifications"

        function toggle(): void {
            notifCenter.panelVisible = !notifCenter.panelVisible;
        }

        function show(): void {
            notifCenter.panelVisible = true;
        }

        function hide(): void {
            notifCenter.panelVisible = false;
        }
    }

    // Click-outside-to-close overlay
    MouseArea {
        anchors.fill: parent
        onClicked: notifCenter.panelVisible = false
    }

    // Main panel content (right-aligned, slides in from right)
    Rectangle {
        width: 380
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: notifCenter.panelVisible ? 0 : -400
        color: Root.Theme.bg

        Behavior on anchors.rightMargin {
            NumberAnimation {
                id: slideAnim
                duration: 250
                easing.type: Easing.OutCubic
                onRunningChanged: {
                    if (!running && !notifCenter.panelVisible) {
                        notifCenter._showing = false;
                    }
                }
            }
        }

        // Block clicks from reaching the overlay
        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // ── Header ──────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 56
                color: Root.Theme.bgSecondary

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Root.Theme.paddingLarge
                    anchors.rightMargin: Root.Theme.paddingLarge
                    spacing: 12

                    // Title + count
                    ColumnLayout {
                        spacing: 2
                        Layout.fillWidth: true

                        Text {
                            text: "Notifications"
                            color: Root.Theme.textPrimary
                            font.family: Root.Theme.fontFamily
                            font.pixelSize: Root.Theme.fontSizeLarge
                            font.weight: Font.DemiBold
                        }

                        Text {
                            text: NotificationService.count + (NotificationService.count === 1 ? " notification" : " notifications")
                            color: Root.Theme.textSecondary
                            font.family: Root.Theme.fontFamily
                            font.pixelSize: 10
                            visible: NotificationService.count > 0
                        }
                    }

                    // Clear All button
                    Rectangle {
                        width: clearAllText.width + 20
                        height: 28
                        radius: Root.Theme.radiusSmall
                        color: clearAllArea.containsMouse ? Root.Theme.bgTertiary : "transparent"
                        border.width: 1
                        border.color: Root.Theme.border
                        visible: NotificationService.count > 0

                        Text {
                            id: clearAllText
                            anchors.centerIn: parent
                            text: "Clear All"
                            color: Root.Theme.textSecondary
                            font.family: Root.Theme.fontFamily
                            font.pixelSize: 11
                        }

                        MouseArea {
                            id: clearAllArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: NotificationService.clearAll()
                        }
                    }
                }

                // Bottom separator
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 1
                    color: Root.Theme.border
                }
            }

            // ── Notification list ───────────────────────────────
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                // Empty state
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 12
                    visible: NotificationService.count === 0

                    Text {
                        text: "󰂚"  // nf-md-bell_outline
                        color: Root.Theme.textSecondary
                        font.family: Root.Theme.fontFamily
                        font.pixelSize: 48
                        opacity: 0.3
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: "No notifications"
                        color: Root.Theme.textSecondary
                        font.family: Root.Theme.fontFamily
                        font.pixelSize: Root.Theme.fontSizeNormal
                        opacity: 0.5
                        Layout.alignment: Qt.AlignHCenter
                    }
                }

                // Notification ListView
                ListView {
                    id: notifListView
                    anchors.fill: parent
                    anchors.topMargin: 8
                    clip: true
                    visible: NotificationService.count > 0

                    model: NotificationService.notifications

                    delegate: NotificationItem {
                        width: notifListView.width
                        notifId: modelData.id
                        appName: modelData.appName
                        summary: modelData.summary
                        body: modelData.body
                        urgency: modelData.urgency
                        timestamp: modelData.timestamp
                        timeAgo: NotificationService.relativeTime(modelData.timestamp)

                        onDismissed: function(id) {
                            NotificationService.removeNotification(id);
                        }
                    }

                    // Smooth scrolling
                    ScrollBar.vertical: ScrollBar {
                        active: true
                        policy: ScrollBar.AsNeeded
                    }
                }
            }
        }
    }

    // Click-outside-to-close handled by fullscreen overlay MouseArea
    Shortcut {
        sequence: "Escape"
        onActivated: notifCenter.panelVisible = false
    }
}
