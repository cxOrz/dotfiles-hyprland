import Quickshell
import QtQuick

import "modules/powermenu" as PowerMenu
import "modules/controlcenter" as ControlCenter

ShellRoot {
    id: root

    // --- Module Instances ---
    // Each component manages its own visibility and IPC handler internally.
    // Nothing auto-opens on startup.

    PowerMenu.PowerMenu {
        id: powerMenu
    }

    ControlCenter.ControlCenter {
        id: controlCenter
    }

    // --- Mutual Exclusivity ---
    // Opening one overlay closes the others.

    Connections {
        target: powerMenu
        function onMenuOpenChanged() {
            if (powerMenu.menuOpen) {
                controlCenter.panelVisible = false;
            }
        }
    }

    Connections {
        target: controlCenter
        function onPanelVisibleChanged() {
            if (controlCenter.panelVisible) {
                powerMenu.menuOpen = false;
            }
        }
    }
}
