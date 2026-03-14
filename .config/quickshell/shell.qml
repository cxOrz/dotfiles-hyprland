import Quickshell
import QtQuick
import Quickshell.Io

import "modules/powermenu" as PowerMenu
import "modules/controlcenter" as ControlCenter
import "modules/notifications" as Notifications

ShellRoot {
    id: root

    // ── Theme persistence — read saved theme on startup ──────────
    Process {
        id: themeReadProc
        command: ["/bin/sh", "-c", "cat ~/.config/quickshell/current-theme 2>/dev/null || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                var theme = text.trim();
                if (theme !== "" && Theme._themes[theme] !== undefined) {
                    Theme.currentTheme = theme;
                }
            }
        }
    }

    Component.onCompleted: themeReadProc.running = true

    // --- Module Instances ---
    // Each component manages its own visibility and IPC handler internally.
    // Nothing auto-opens on startup.

    PowerMenu.PowerMenu {
        id: powerMenu
    }

    ControlCenter.ControlCenter {
        id: controlCenter
    }

    Notifications.NotificationCenter {
        id: notificationCenter
    }

    // --- Mutual Exclusivity ---

    Connections {
        target: powerMenu
        function onMenuOpenChanged() {
            if (powerMenu.menuOpen) {
                controlCenter.panelVisible = false;
                notificationCenter.panelVisible = false;
            }
        }
    }

    Connections {
        target: controlCenter
        function onPanelVisibleChanged() {
            if (controlCenter.panelVisible) {
                powerMenu.menuOpen = false;
                notificationCenter.panelVisible = false;
            }
        }
    }

    Connections {
        target: notificationCenter
        function onPanelVisibleChanged() {
            if (notificationCenter.panelVisible) {
                powerMenu.menuOpen = false;
                controlCenter.panelVisible = false;
            }
        }
    }
}
