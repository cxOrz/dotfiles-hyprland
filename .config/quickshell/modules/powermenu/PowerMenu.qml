import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../.." as Root

Scope {
    id: root
    property bool menuOpen: false
    property int selectedIndex: 0
    readonly property int buttonCount: 4

    // Reset selection every time the menu opens
    onMenuOpenChanged: {
        if (menuOpen) selectedIndex = 0;
    }

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

            // Dim overlay — lighter than before so blur on contentBox is visible
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.35)

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.menuOpen = false
                }
            }

            // Centered content box — semi-transparent so hyprland blur shines through
            Rectangle {
                id: contentBox
                anchors.centerIn: parent
                width: contentRow.implicitWidth + 28 * 2
                height: contentRow.implicitHeight + 24 * 2
                radius: 20
                // Semi-transparent panel background — follows active theme
                color: Qt.rgba(Root.Theme.panelBg.r, Root.Theme.panelBg.g, Root.Theme.panelBg.b, 0.82)
                border.color: Root.Theme.panelBorder
                border.width: 1

                opacity: 0
                scale: 0.93

                Component.onCompleted: appearAnim.start()

                ParallelAnimation {
                    id: appearAnim
                    NumberAnimation {
                        target: contentBox; property: "opacity"
                        to: 1; duration: 200; easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: contentBox; property: "scale"
                        to: 1; duration: 200; easing.type: Easing.OutCubic
                    }
                }

                // Block clicks from reaching the background dismiss area
                MouseArea { anchors.fill: parent }

                RowLayout {
                    id: contentRow
                    anchors.centerIn: parent
                    spacing: 12

                    PowerButton {
                        icon: "󰐥"
                        label: "Shutdown"
                        selected: root.selectedIndex === 0
                        onClicked: { shutdownProc.startDetached(); root.menuOpen = false; }
                    }

                    PowerButton {
                        icon: "󰜉"
                        label: "Reboot"
                        selected: root.selectedIndex === 1
                        onClicked: { rebootProc.startDetached(); root.menuOpen = false; }
                    }

                    PowerButton {
                        icon: "󰌾"
                        label: "Lock"
                        selected: root.selectedIndex === 2
                        onClicked: { lockProc.startDetached(); root.menuOpen = false; }
                    }

                    PowerButton {
                        icon: "󰤄"
                        label: "Suspend"
                        selected: root.selectedIndex === 3
                        onClicked: { suspendProc.startDetached(); root.menuOpen = false; }
                    }
                }
            }

            // Keyboard navigation handler
            Item {
                focus: true

                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Escape) {
                        root.menuOpen = false;
                        event.accepted = true;

                    } else if (event.key === Qt.Key_Left ||
                               (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                        root.selectedIndex = (root.selectedIndex - 1 + root.buttonCount) % root.buttonCount;
                        event.accepted = true;

                    } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) {
                        root.selectedIndex = (root.selectedIndex + 1) % root.buttonCount;
                        event.accepted = true;

                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter ||
                               event.key === Qt.Key_Space) {
                        switch (root.selectedIndex) {
                            case 0: shutdownProc.startDetached(); break;
                            case 1: rebootProc.startDetached(); break;
                            case 2: lockProc.startDetached(); break;
                            case 3: suspendProc.startDetached(); break;
                        }
                        root.menuOpen = false;
                        event.accepted = true;
                    }
                }
            }
        }
    }

    // Process definitions outside Loader so they persist for startDetached calls
    Process { id: shutdownProc; command: ["systemctl", "poweroff"] }
    Process { id: rebootProc;   command: ["systemctl", "reboot"] }
    Process { id: lockProc;     command: ["hyprlock"] }
    Process { id: suspendProc;  command: ["systemctl", "suspend"] }

    IpcHandler {
        target: "powermenu"
        function toggle(): void { root.menuOpen = !root.menuOpen; }
        function open(): void   { root.menuOpen = true; }
        function close(): void  { root.menuOpen = false; }
    }
}
