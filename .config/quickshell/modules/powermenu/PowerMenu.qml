import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../.." as Root

Scope {
    id: root
    property bool menuOpen: false

    Loader {
        active: root.menuOpen

        sourceComponent: PanelWindow {
            id: menuWindow
            visible: true

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:powermenu"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            color: "transparent"

            // Semi-transparent overlay background + click-outside-to-close
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(Root.Theme.bg.r, Root.Theme.bg.g, Root.Theme.bg.b, 0.7)

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.menuOpen = false
                }
            }

            // Centered content box
            Rectangle {
                id: contentBox
                anchors.centerIn: parent
                width: contentRow.implicitWidth + Root.Theme.paddingLarge * 2
                height: contentRow.implicitHeight + Root.Theme.paddingLarge * 2
                radius: Root.Theme.radiusLarge
                color: Root.Theme.bgSecondary
                border.color: Root.Theme.border
                border.width: 1

                // Block clicks from reaching the background dismiss area
                MouseArea {
                    anchors.fill: parent
                }

                RowLayout {
                    id: contentRow
                    anchors.centerIn: parent
                    spacing: Root.Theme.paddingLarge

                    PowerButton {
                        icon: "󰐥"
                        label: "Shutdown"
                        onClicked: {
                            shutdownProc.startDetached();
                            root.menuOpen = false;
                        }
                    }

                    PowerButton {
                        icon: "󰜉"
                        label: "Reboot"
                        onClicked: {
                            rebootProc.startDetached();
                            root.menuOpen = false;
                        }
                    }

                    PowerButton {
                        icon: "󰌾"
                        label: "Lock"
                        onClicked: {
                            lockProc.startDetached();
                            root.menuOpen = false;
                        }
                    }

                    PowerButton {
                        icon: "󰤄"
                        label: "Suspend"
                        onClicked: {
                            suspendProc.startDetached();
                            root.menuOpen = false;
                        }
                    }
                }
            }

            // Escape key handler — needs focus to receive key events
            Item {
                focus: true
                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Escape) {
                        root.menuOpen = false;
                    }
                }
            }
        }
    }

    // Process definitions (outside Loader so they persist for startDetached calls)
    Process {
        id: shutdownProc
        command: ["systemctl", "poweroff"]
    }

    Process {
        id: rebootProc
        command: ["systemctl", "reboot"]
    }

    Process {
        id: lockProc
        command: ["hyprlock"]
    }

    Process {
        id: suspendProc
        command: ["systemctl", "suspend"]
    }

    // IPC handler for external toggle: `qs ipc call powermenu toggle`
    IpcHandler {
        target: "powermenu"

        function toggle(): void {
            root.menuOpen = !root.menuOpen;
        }

        function open(): void {
            root.menuOpen = true;
        }

        function close(): void {
            root.menuOpen = false;
        }
    }
}
