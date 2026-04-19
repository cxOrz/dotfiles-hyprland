import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../.." as Root

// Notification Center — bottom-sliding panel (ChromeOS / MD3 style)
// Displays dunst notification history in a scrollable card list.
Scope {
    id: notifCenter

    property bool panelVisible: false
    property bool _showing: false
    property bool _panelOpen: false

    onPanelVisibleChanged: {
        if (panelVisible) {
            _showing = true;
        } else {
            _panelOpen = false;
        }
    }

    // ── IPC Handler ──────────────────────────────────────────────
    IpcHandler {
        target: "notifications"

        function toggle(): void { notifCenter.panelVisible = !notifCenter.panelVisible; }
        function show(): void { notifCenter.panelVisible = true; }
        function hide(): void { notifCenter.panelVisible = false; }
    }

    // ── Overlay window / panel ──────────────────────────────────
    Loader {
        active: notifCenter._showing

        sourceComponent: PanelWindow {
            id: panelWindow
            visible: true

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            color: "transparent"
            exclusionMode: ExclusionMode.Ignore

            WlrLayershell.namespace: "quickshell:notifications"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            Component.onCompleted: openDelayTimer.start()

            Timer {
                id: openDelayTimer
                interval: 16
                repeat: false
                onTriggered: if (notifCenter.panelVisible) notifCenter._panelOpen = true
            }

            Shortcut {
                sequence: "Escape"
                onActivated: notifCenter.panelVisible = false
            }

            // Click-outside close
            MouseArea {
                anchors.fill: parent
                onClicked: notifCenter.panelVisible = false
            }

            // Clip region: bottom edge at shelf top
            Item {
                id: panelClip
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Root.Theme.shelfHeight
                clip: true

                Rectangle {
                    id: panel

                    width: Root.Theme.panelWidth
                    anchors.right: parent.right
                    anchors.rightMargin: Root.Theme.spacingSmall

                    height: Math.min(panelContent.implicitHeight, panelClip.height - Root.Theme.spacingSmall * 2)

                    states: [
                        State {
                            name: "visible"
                            when: notifCenter._panelOpen
                            PropertyChanges {
                                target: panel
                                y: panel.parent.height - panel.height - Root.Theme.spacingSmall
                            }
                        },
                        State {
                            name: "hidden"
                            when: !notifCenter._panelOpen
                            PropertyChanges {
                                target: panel
                                y: panel.parent.height
                            }
                        }
                    ]

                    transitions: [
                        Transition {
                            from: "hidden"
                            to: "visible"
                            NumberAnimation {
                                property: "y"
                                duration: Root.Theme.animDuration
                                easing.type: Easing.OutCubic
                            }
                        },
                        Transition {
                            from: "visible"
                            to: "hidden"
                            SequentialAnimation {
                                NumberAnimation {
                                    property: "y"
                                    duration: Root.Theme.animDuration
                                    easing.type: Easing.OutCubic
                                }
                                ScriptAction {
                                    script: notifCenter._showing = false
                                }
                            }
                        }
                    ]

                    radius: Root.Theme.panelRadius
                    color: Qt.rgba(Root.Theme.panelBg.r, Root.Theme.panelBg.g, Root.Theme.panelBg.b, 0.78)
                    border.width: 1
                    border.color: Qt.rgba(Root.Theme.panelBorder.r,
                                           Root.Theme.panelBorder.g,
                                           Root.Theme.panelBorder.b,
                                           0.5)
                    clip: true

                    // Block click-through
                    MouseArea {
                        anchors.fill: parent
                    }

                    ColumnLayout {
                        id: panelContent
                        width: panel.width
                        spacing: 0

                        // ── Notification List ───────────────────────
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: NotificationService.count > 0
                                ? Math.min(notifListView.contentHeight + 20, 400)
                                : 160

                            // Empty state
                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 12
                                visible: NotificationService.count === 0

                                Text {
                                    text: "󰂚"
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

                            // Scrollable notification list
                            ListView {
                                id: notifListView
                                anchors.fill: parent
                                anchors.topMargin: 12
                                anchors.bottomMargin: 8
                                clip: true
                                visible: NotificationService.count > 0
                                spacing: 0
                                boundsMovement: Flickable.StopAtBounds

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

                                ScrollBar.vertical: ScrollBar {
                                    active: true
                                    policy: ScrollBar.AsNeeded
                                }
                            }
                        }

                        // ── Footer — Clear All ──────────────────────
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 44
                            Layout.topMargin: 0
                            Layout.bottomMargin: 8
                            visible: NotificationService.count > 0

                            // Clear all — text button, right-aligned
                            Rectangle {
                                anchors.right: parent.right
                                anchors.rightMargin: Root.Theme.paddingLarge
                                anchors.verticalCenter: parent.verticalCenter
                                width: clearAllLabel.implicitWidth + 24
                                height: 36
                                radius: 18
                                color: clearAllMA.containsMouse
                                    ? Qt.rgba(Root.Theme.textSecondary.r, Root.Theme.textSecondary.g, Root.Theme.textSecondary.b, 0.12)
                                    : "transparent"

                                Behavior on color { ColorAnimation { duration: 120 } }

                                Text {
                                    id: clearAllLabel
                                    anchors.centerIn: parent
                                    text: "Clear all"
                                    color: Root.Theme.textSecondary
                                    font.family: Root.Theme.fontFamily
                                    font.pixelSize: Root.Theme.fontSizeNormal
                                    font.weight: Font.DemiBold
                                }

                                MouseArea {
                                    id: clearAllMA
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: NotificationService.clearAll()
                                }
                            }
                        }
                    }
                }  // end Rectangle (panel)
            }  // end Item (panelClip)
        }
    }
}
