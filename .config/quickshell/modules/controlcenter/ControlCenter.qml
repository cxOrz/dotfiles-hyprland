import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../.." as Root
import "../notifications" as Notifications

// Control Center — Windows 10 Action Center style
// Main page: quick tiles (WiFi/BT) + Volume + Notifications
// Sub-pages: WifiSection and BluetoothSection slide in from the right
//
// Uses Scope > Loader > PanelWindow pattern so the Wayland surface
// is created fresh with transparent color (required for rounded corners).
Scope {
    id: controlCenter

    property bool panelVisible: false
    property bool _showing: false     // true while Loader is active (includes close animation)
    property bool _panelOpen: false   // drives the margin slide animation inside PanelWindow
    property string currentPage: "main"  // "main" | "wifi" | "bluetooth"

    // Lightweight status for tiles
    property string wifiStatus: ""       // e.g. "HomeNetwork" | "" (not connected) | null (disabled)
    property bool   wifiEnabled: true
    property bool   btEnabled: true
    property int    btConnectedCount: 0

    onPanelVisibleChanged: {
        if (panelVisible) {
            _showing = true;
            // _panelOpen is set to true in PanelWindow.Component.onCompleted
            // to ensure the slide-in animation triggers after creation
            wifiStatusProc.running = true;
            btStatusProc.running = true;
            Notifications.NotificationService.refresh();
        } else {
            // Trigger slide-out; Loader deactivates when animation completes
            _panelOpen = false;
            resetPageTimer.running = true;
        }
    }

    Timer {
        id: resetPageTimer
        interval: 300
        repeat: false
        onTriggered: controlCenter.currentPage = "main"
    }

    // ── Tile status polling ───────────────────────────────────────

    // WiFi: nmcli -t -f TYPE,STATE,CONNECTION device
    Process {
        id: wifiStatusProc
        command: ["nmcli", "-t", "-f", "TYPE,STATE,CONNECTION", "device"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim().split("\n");
                var found = false;
                for (var i = 0; i < lines.length; i++) {
                    // Some lines may have escaped colons; split on unescaped ":"
                    var parts = lines[i].split(":");
                    if (parts.length >= 1 && parts[0] === "wifi") {
                        found = true;
                        var state = parts.length >= 2 ? parts[1] : "";
                        var conn  = parts.length >= 3 ? parts.slice(2).join(":") : "";
                        if (state === "connected" || state === "connecting (getting IP address)" || state.startsWith("connecting")) {
                            controlCenter.wifiEnabled = true;
                            controlCenter.wifiStatus = conn !== "" ? conn : "Connected";
                        } else if (state === "unavailable" || state === "unmanaged") {
                            controlCenter.wifiEnabled = false;
                            controlCenter.wifiStatus = "";
                        } else {
                            controlCenter.wifiEnabled = true;
                            controlCenter.wifiStatus = "";
                        }
                        break;
                    }
                }
                if (!found) {
                    controlCenter.wifiEnabled = false;
                    controlCenter.wifiStatus = "";
                }
            }
        }
    }

    // BT: bluetoothctl show
    Process {
        id: btStatusProc
        command: ["bluetoothctl", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                controlCenter.btEnabled = text.includes("Powered: yes");
            }
        }
    }

    // BT connected count: bluetoothctl devices Connected
    Process {
        id: btConnectedProc
        command: ["bluetoothctl", "devices", "Connected"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim().split("\n");
                var count = 0;
                for (var i = 0; i < lines.length; i++) {
                    if (lines[i].trim().startsWith("Device")) count++;
                }
                controlCenter.btConnectedCount = count;
            }
        }
    }

    // Poll tile status every 8s while panel is open
    Timer {
        interval: 8000
        running: controlCenter.panelVisible
        repeat: true
        onTriggered: {
            wifiStatusProc.running = true;
            btStatusProc.running = true;
            btConnectedProc.running = true;
        }
    }

    // ── IPC ──────────────────────────────────────────────────────

    IpcHandler {
        target: "controlcenter"

        function toggle(): void { controlCenter.panelVisible = !controlCenter.panelVisible; }
        function show(): void   { controlCenter.panelVisible = true; }
        function hide(): void   { controlCenter.panelVisible = false; }
    }

    // Legacy "notifications" IPC target — redirects to controlcenter
    IpcHandler {
        target: "notifications"

        function toggle(): void { controlCenter.panelVisible = !controlCenter.panelVisible; }
        function show(): void   { controlCenter.panelVisible = true; }
        function hide(): void   { controlCenter.panelVisible = false; }
    }

    // ── PanelWindow via Loader (fresh Wayland surface = working alpha) ──

    Loader {
        active: controlCenter._showing

        sourceComponent: PanelWindow {
            id: panelWindow
            visible: true

            implicitWidth: 400
            color: "transparent"

            anchors {
                top: true
                right: true
                bottom: true
            }

            margins.top: 96
            margins.bottom: 96

            exclusionMode: ExclusionMode.Ignore
            focusable: true

            WlrLayershell.namespace: "quickshell:controlcenter"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            // Slide-in from right — bound to Scope-level _panelOpen
            margins.right: controlCenter._panelOpen ? 0 : -(implicitWidth + 20)

            Behavior on margins.right {
                NumberAnimation {
                    duration: 250
                    easing.type: Easing.OutQuart
                    onRunningChanged: {
                        if (!running && !controlCenter._panelOpen) {
                            controlCenter._showing = false;
                        }
                    }
                }
            }

            // On creation, trigger slide-in on the next frame
            Component.onCompleted: {
                controlCenter._panelOpen = true;
            }

            Shortcut {
                sequence: "Escape"
                onActivated: {
                    if (controlCenter.currentPage !== "main") {
                        controlCenter.currentPage = "main";
                    } else {
                        controlCenter.panelVisible = false;
                    }
                }
            }

            // ── Main panel ───────────────────────────────────────────────

            Rectangle {
                anchors.fill: parent
                color: Root.Theme.bg
                radius: Root.Theme.radiusLarge

                // Square off bottom-right corner (panel is flush against right screen edge)
                Rectangle {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    width: Root.Theme.radiusLarge
                    height: Root.Theme.radiusLarge
                    color: parent.color
                }

                // Square off top-right corner (matches header color)
                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    width: Root.Theme.radiusLarge
                    height: Root.Theme.radiusLarge
                    color: Root.Theme.bgSecondary
                }

                // Page container — clips sliding pages
                Item {
                    id: pageContainer
                    anchors.fill: parent
                    clip: true

                    // ════════════════════════════════════════════════════
                    // MAIN PAGE
                    // ════════════════════════════════════════════════════
                    Item {
                        id: mainPage
                        width: parent.width
                        height: parent.height
                        x: controlCenter.currentPage === "main" ? 0 : -pageContainer.width

                        Behavior on x {
                            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 0

                            // ── Header ───────────────────────────────
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 56
                                color: Root.Theme.bgSecondary
                                radius: Root.Theme.radiusLarge

                                // Square off bottom corners
                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    height: Root.Theme.radiusLarge
                                    color: parent.color
                                }

                                // Square off top-right corner
                                Rectangle {
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    width: Root.Theme.radiusLarge
                                    height: Root.Theme.radiusLarge
                                    color: parent.color
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: Root.Theme.paddingLarge
                                    anchors.rightMargin: Root.Theme.paddingLarge

                                    Text {
                                        text: "Control Center"
                                        color: Root.Theme.textPrimary
                                        font.family: Root.Theme.fontFamily
                                        font.pixelSize: Root.Theme.fontSizeLarge
                                        font.weight: Font.DemiBold
                                        Layout.fillWidth: true
                                    }

                                    Rectangle {
                                        width: 28; height: 28
                                        radius: Root.Theme.radiusSmall
                                        color: closeHover.containsMouse ? Root.Theme.bgTertiary : "transparent"

                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰅖"
                                            color: closeHover.containsMouse ? Root.Theme.textPrimary : Root.Theme.textSecondary
                                            font.family: Root.Theme.fontFamily
                                            font.pixelSize: Root.Theme.fontSizeNormal
                                        }

                                        MouseArea {
                                            id: closeHover
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: controlCenter.panelVisible = false
                                        }
                                    }
                                }

                                Rectangle {
                                    anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                                    height: 1; color: Root.Theme.border
                                }
                            }

                            // ── Quick Tiles (WiFi + Bluetooth) ───────
                            GridLayout {
                                Layout.fillWidth: true
                                Layout.leftMargin: Root.Theme.paddingNormal
                                Layout.rightMargin: Root.Theme.paddingNormal
                                Layout.topMargin: 10
                                Layout.bottomMargin: 10
                                columns: 2
                                rowSpacing: 10
                                columnSpacing: 10

                                // WiFi tile
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 72
                                    radius: Root.Theme.radiusLarge
                                    color: wifiTileMA.containsMouse
                                        ? (controlCenter.wifiEnabled
                                            ? Qt.rgba(Root.Theme.accent.r, Root.Theme.accent.g, Root.Theme.accent.b, 0.20)
                                            : Root.Theme.bgTertiary)
                                        : (controlCenter.wifiEnabled
                                            ? Qt.rgba(Root.Theme.accent.r, Root.Theme.accent.g, Root.Theme.accent.b, 0.12)
                                            : Root.Theme.bgSecondary)
                                    border.width: 1
                                    border.color: controlCenter.wifiEnabled
                                        ? Qt.rgba(Root.Theme.accent.r, Root.Theme.accent.g, Root.Theme.accent.b, 0.3)
                                        : Qt.rgba(Root.Theme.border.r, Root.Theme.border.g, Root.Theme.border.b, 0.6)

                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Behavior on border.color { ColorAnimation { duration: 150 } }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 10
                                        spacing: 10

                                        // Icon circle
                                        Rectangle {
                                            Layout.preferredWidth: 36
                                            Layout.preferredHeight: 36
                                            radius: 18
                                            color: controlCenter.wifiEnabled
                                                ? Root.Theme.accent
                                                : Qt.rgba(Root.Theme.textSecondary.r, Root.Theme.textSecondary.g, Root.Theme.textSecondary.b, 0.15)

                                            Behavior on color { ColorAnimation { duration: 200 } }

                                            Text {
                                                anchors.centerIn: parent
                                                text: controlCenter.wifiEnabled ? "󰖩" : "󰖪"
                                                font.family: Root.Theme.fontFamily
                                                font.pixelSize: 16
                                                color: controlCenter.wifiEnabled ? "#ffffff" : Root.Theme.textSecondary
                                            }
                                        }

                                        // Text column
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2

                                            Text {
                                                text: "Wi-Fi"
                                                font.family: Root.Theme.fontFamily
                                                font.pixelSize: Root.Theme.fontSizeNormal
                                                font.weight: Font.DemiBold
                                                color: controlCenter.wifiEnabled ? Root.Theme.textPrimary : Root.Theme.textSecondary
                                                Layout.fillWidth: true
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                text: {
                                                    if (!controlCenter.wifiEnabled) return "Disabled";
                                                    if (controlCenter.wifiStatus !== "") return controlCenter.wifiStatus;
                                                    return "Not connected";
                                                }
                                                font.family: Root.Theme.fontFamily
                                                font.pixelSize: Root.Theme.fontSizeXS
                                                color: controlCenter.wifiEnabled && controlCenter.wifiStatus !== ""
                                                    ? Qt.rgba(Root.Theme.accent.r, Root.Theme.accent.g, Root.Theme.accent.b, 0.85)
                                                    : Qt.rgba(Root.Theme.textSecondary.r, Root.Theme.textSecondary.g, Root.Theme.textSecondary.b, 0.7)
                                                Layout.fillWidth: true
                                                elide: Text.ElideRight
                                            }
                                        }

                                        // Chevron
                                        Text {
                                            text: "󰅂"
                                            font.family: Root.Theme.fontFamily
                                            font.pixelSize: 14
                                            color: Qt.rgba(Root.Theme.textSecondary.r, Root.Theme.textSecondary.g, Root.Theme.textSecondary.b, 0.4)
                                        }
                                    }

                                    MouseArea {
                                        id: wifiTileMA
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: controlCenter.currentPage = "wifi"
                                    }
                                }

                                // Bluetooth tile
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 72
                                    radius: Root.Theme.radiusLarge
                                    color: btTileMA.containsMouse
                                        ? (controlCenter.btEnabled
                                            ? Qt.rgba(Root.Theme.accent.r, Root.Theme.accent.g, Root.Theme.accent.b, 0.20)
                                            : Root.Theme.bgTertiary)
                                        : (controlCenter.btEnabled
                                            ? Qt.rgba(Root.Theme.accent.r, Root.Theme.accent.g, Root.Theme.accent.b, 0.12)
                                            : Root.Theme.bgSecondary)
                                    border.width: 1
                                    border.color: controlCenter.btEnabled
                                        ? Qt.rgba(Root.Theme.accent.r, Root.Theme.accent.g, Root.Theme.accent.b, 0.3)
                                        : Qt.rgba(Root.Theme.border.r, Root.Theme.border.g, Root.Theme.border.b, 0.6)

                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Behavior on border.color { ColorAnimation { duration: 150 } }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 10
                                        spacing: 10

                                        // Icon circle
                                        Rectangle {
                                            Layout.preferredWidth: 36
                                            Layout.preferredHeight: 36
                                            radius: 18
                                            color: controlCenter.btEnabled
                                                ? Root.Theme.accent
                                                : Qt.rgba(Root.Theme.textSecondary.r, Root.Theme.textSecondary.g, Root.Theme.textSecondary.b, 0.15)

                                            Behavior on color { ColorAnimation { duration: 200 } }

                                            Text {
                                                anchors.centerIn: parent
                                                text: controlCenter.btEnabled ? "󰂯" : "󰂲"
                                                font.family: Root.Theme.fontFamily
                                                font.pixelSize: 16
                                                color: controlCenter.btEnabled ? "#ffffff" : Root.Theme.textSecondary
                                            }
                                        }

                                        // Text column
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2

                                            Text {
                                                text: "Bluetooth"
                                                font.family: Root.Theme.fontFamily
                                                font.pixelSize: Root.Theme.fontSizeNormal
                                                font.weight: Font.DemiBold
                                                color: controlCenter.btEnabled ? Root.Theme.textPrimary : Root.Theme.textSecondary
                                                Layout.fillWidth: true
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                text: {
                                                    if (!controlCenter.btEnabled) return "Disabled";
                                                    if (controlCenter.btConnectedCount > 0)
                                                        return controlCenter.btConnectedCount + " connected";
                                                    return "No devices";
                                                }
                                                font.family: Root.Theme.fontFamily
                                                font.pixelSize: Root.Theme.fontSizeXS
                                                color: controlCenter.btEnabled && controlCenter.btConnectedCount > 0
                                                    ? Qt.rgba(Root.Theme.accent.r, Root.Theme.accent.g, Root.Theme.accent.b, 0.85)
                                                    : Qt.rgba(Root.Theme.textSecondary.r, Root.Theme.textSecondary.g, Root.Theme.textSecondary.b, 0.7)
                                                Layout.fillWidth: true
                                                elide: Text.ElideRight
                                            }
                                        }

                                        // Chevron
                                        Text {
                                            text: "󰅂"
                                            font.family: Root.Theme.fontFamily
                                            font.pixelSize: 14
                                            color: Qt.rgba(Root.Theme.textSecondary.r, Root.Theme.textSecondary.g, Root.Theme.textSecondary.b, 0.4)
                                        }
                                    }

                                    MouseArea {
                                        id: btTileMA
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: controlCenter.currentPage = "bluetooth"
                                    }
                                }
                            }

                            // ── Separator ────────────────────────────
                            Rectangle {
                                Layout.fillWidth: true
                                height: 1
                                color: Root.Theme.border
                            }

                            // ── Volume Section ───────────────────────
                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: volSection.implicitHeight + 2 * Root.Theme.paddingNormal
                                Layout.leftMargin: Root.Theme.paddingNormal
                                Layout.rightMargin: Root.Theme.paddingNormal

                                VolumeSection {
                                    id: volSection
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            // ── Separator ────────────────────────────
                            Rectangle {
                                Layout.fillWidth: true
                                height: 1
                                color: Root.Theme.border
                            }

                            // ── Notification Header ──────────────────
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 48
                                color: "transparent"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: Root.Theme.paddingLarge
                                    anchors.rightMargin: Root.Theme.paddingLarge
                                    spacing: 12

                                    Text {
                                        text: "󰂚"
                                        font.family: Root.Theme.fontFamily
                                        font.pixelSize: Root.Theme.fontSizeNormal
                                        color: Notifications.NotificationService.count > 0 ? Root.Theme.accent : Root.Theme.textSecondary
                                        opacity: Notifications.NotificationService.count > 0 ? 1.0 : 0.4
                                    }

                                    Text {
                                        text: "Notifications"
                                        color: Root.Theme.textPrimary
                                        font.family: Root.Theme.fontFamily
                                        font.pixelSize: Root.Theme.fontSizeNormal
                                        font.weight: Font.DemiBold
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        visible: Notifications.NotificationService.count > 0
                                        text: Notifications.NotificationService.count
                                        color: Root.Theme.textSecondary
                                        font.family: Root.Theme.fontFamily
                                        font.pixelSize: Root.Theme.fontSizeNormal
                                    }

                                    Rectangle {
                                        visible: Notifications.NotificationService.count > 0
                                        implicitWidth: clearTxt.implicitWidth + 16
                                        height: 24
                                        radius: Root.Theme.radiusSmall
                                        color: clearHover.containsMouse ? Root.Theme.bgTertiary : "transparent"
                                        border.width: 1
                                        border.color: Root.Theme.border

                                        Text {
                                            id: clearTxt
                                            anchors.centerIn: parent
                                            text: "Clear"
                                            color: Root.Theme.textSecondary
                                            font.family: Root.Theme.fontFamily
                                            font.pixelSize: Root.Theme.fontSizeSmall
                                        }

                                        MouseArea {
                                            id: clearHover
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: Notifications.NotificationService.clearAll()
                                        }
                                    }
                                }
                            }

                            // ── Notification List ────────────────────
                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                // Empty state
                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 12
                                    visible: Notifications.NotificationService.count === 0

                                    Text {
                                        text: "󰂚"
                                        color: Root.Theme.textSecondary
                                        font.family: Root.Theme.fontFamily
                                        font.pixelSize: 40
                                        opacity: 0.2
                                        Layout.alignment: Qt.AlignHCenter
                                    }

                                    Text {
                                        text: "No notifications"
                                        color: Root.Theme.textSecondary
                                        font.family: Root.Theme.fontFamily
                                        font.pixelSize: Root.Theme.fontSizeNormal
                                        opacity: 0.4
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                }

                                // List
                                ListView {
                                    id: notifListView
                                    anchors.fill: parent
                                    anchors.topMargin: 4
                                    clip: true
                                    visible: Notifications.NotificationService.count > 0
                                    model: Notifications.NotificationService.notifications

                                    delegate: Notifications.NotificationItem {
                                        width: notifListView.width
                                        notifId: modelData.id
                                        appName: modelData.appName
                                        summary: modelData.summary
                                        body: modelData.body
                                        urgency: modelData.urgency
                                        timestamp: modelData.timestamp
                                        timeAgo: Notifications.NotificationService.relativeTime(modelData.timestamp)

                                        onDismissed: function(id) {
                                            Notifications.NotificationService.removeNotification(id);
                                        }
                                    }

                                    ScrollBar.vertical: ScrollBar {
                                        active: true
                                        policy: ScrollBar.AsNeeded
                                    }
                                }
                            }
                        }
                    }

                    // ════════════════════════════════════════════════════
                    // WIFI SUB-PAGE
                    // ════════════════════════════════════════════════════
                    WifiSection {
                        id: wifiPage
                        width: pageContainer.width
                        height: pageContainer.height
                        x: controlCenter.currentPage === "wifi" ? 0 : pageContainer.width

                        Behavior on x {
                            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                        }

                        onBack: {
                            controlCenter.currentPage = "main";
                            // Refresh tile status after returning
                            wifiStatusProc.running = true;
                        }
                    }

                    // ════════════════════════════════════════════════════
                    // BLUETOOTH SUB-PAGE
                    // ════════════════════════════════════════════════════
                    BluetoothSection {
                        id: btPage
                        width: pageContainer.width
                        height: pageContainer.height
                        x: controlCenter.currentPage === "bluetooth" ? 0 : pageContainer.width

                        Behavior on x {
                            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                        }

                        onBack: {
                            controlCenter.currentPage = "main";
                            // Refresh tile status after returning
                            btStatusProc.running = true;
                            btConnectedProc.running = true;
                        }
                    }
                }
            }
        }
    }
}
