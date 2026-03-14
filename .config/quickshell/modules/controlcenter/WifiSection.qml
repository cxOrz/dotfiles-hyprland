import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Io
import "../.." as Root

// WiFi Sub-Page — full-height panel for WiFi management
// Parent navigates here via currentPage = "wifi"; back() signal returns to main
Item {
    id: wifiPanel

    signal back()

    property bool wifiEnabled: true
    property bool scanning: false
    property string errorMessage: ""

    // Inline password input state
    property string pendingSSID: ""
    property string pendingSecurity: ""
    property bool showConnect: false


    // ── Processes ────────────────────────────────────────────────

    Process {
        id: radioStatusProc
        command: ["nmcli", "radio", "wifi"]
        stdout: StdioCollector {
            onStreamFinished: {
                var wasEnabled = wifiPanel.wifiEnabled;
                wifiPanel.wifiEnabled = (text.trim() === "enabled");
                if (wifiPanel.wifiEnabled && !wasEnabled) {
                    listNetworksProc.running = true;
                }
                if (!wifiPanel.wifiEnabled) {
                    networkListModel.clear();
                }
            }
        }
    }

    Process {
        id: listNetworksProc
        command: ["nmcli", "-t", "-f", "SSID,SIGNAL,SECURITY,IN-USE", "dev", "wifi", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                wifiPanel.scanning = false;
                wifiPanel.parseNetworks(text);
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                wifiPanel.scanning = false;
                wifiPanel.errorMessage = "Failed to scan (code " + exitCode + ")";
            }
        }
    }

    Process {
        id: toggleWifiProc
        stdout: StdioCollector {}
        onExited: (exitCode, exitStatus) => { radioStatusProc.running = true; }
    }

    Process {
        id: connectProc
        stdout: StdioCollector {}
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                wifiPanel.errorMessage = "Connection failed";
            } else {
                wifiPanel.errorMessage = "";
                wifiPanel.showConnect = false;
                wifiPanel.pendingSSID = "";
            }
            listNetworksProc.running = true;
        }
    }

    Process {
        id: rescanProc
        command: ["nmcli", "dev", "wifi", "rescan"]
        stdout: StdioCollector {}
        onExited: (exitCode, exitStatus) => { listNetworksProc.running = true; }
    }

    Timer {
        id: refreshTimer
        interval: 10000
        running: wifiPanel.visible && wifiPanel.wifiEnabled
        repeat: true
        onTriggered: {
            if (!wifiPanel.scanning) {
                wifiPanel.scanning = true;
                listNetworksProc.running = true;
            }
        }
    }

    Component.onCompleted: {
        radioStatusProc.running = true;
        scanning = true;
        listNetworksProc.running = true;
    }

    // ── Logic ────────────────────────────────────────────────────

    function parseNetworks(output) {
        var lines = output.trim().split("\n");
        var networks = [];
        var seen = {};

        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim();
            if (line === "") continue;

            var lastColon = line.lastIndexOf(':');
            var inUse = line.substring(lastColon + 1).trim();
            var rest = line.substring(0, lastColon);

            var secColon = rest.lastIndexOf(':');
            var security = rest.substring(secColon + 1).trim();
            rest = rest.substring(0, secColon);

            var sigColon = rest.lastIndexOf(':');
            var signal = parseInt(rest.substring(sigColon + 1).trim());
            var ssid = rest.substring(0, sigColon).replace(/\\:/g, ':');

            if (isNaN(signal)) signal = 0;
            if (ssid === "") continue;

            if (seen[ssid] !== undefined) {
                var idx = seen[ssid];
                if (networks[idx].signal < signal) {
                    networks[idx].signal = signal;
                    networks[idx].security = security;
                }
                if (inUse === "*") networks[idx].connected = true;
                continue;
            }

            seen[ssid] = networks.length;
            networks.push({ ssid: ssid, signal: signal, security: security, connected: inUse === "*" });
        }

        networks.sort(function(a, b) {
            if (a.connected && !b.connected) return -1;
            if (!a.connected && b.connected) return 1;
            return b.signal - a.signal;
        });

        networkListModel.clear();
        for (var j = 0; j < networks.length; j++) networkListModel.append(networks[j]);
        errorMessage = "";
    }

    function toggleWifi() {
        if (wifiEnabled) {
            toggleWifiProc.command = ["nmcli", "radio", "wifi", "off"];
        } else {
            toggleWifiProc.command = ["nmcli", "radio", "wifi", "on"];
        }
        toggleWifiProc.running = true;
    }

    function connectToNetwork(ssid, password) {
        if (password && password.length > 0) {
            connectProc.command = ["nmcli", "dev", "wifi", "connect", ssid, "password", password];
        } else {
            connectProc.command = ["nmcli", "dev", "wifi", "connect", ssid];
        }
        connectProc.running = true;
    }

    function signalIcon(strength) {
        if (strength <= 25) return "󰤯";
        if (strength <= 50) return "󰤟";
        if (strength <= 75) return "󰤢";
        return "󰤨";
    }

    ListModel { id: networkListModel }

    // ── UI ───────────────────────────────────────────────────────

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Header ──────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 56

            // Top-rounded background: full-radius rect + bottom fill to square off bottom corners
            Rectangle {
                anchors.fill: parent
                radius: Root.Theme.panelRadius
                color: Root.Theme.surface
            }
            Rectangle {
                anchors.left: parent.left; anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: Root.Theme.panelRadius
                color: Root.Theme.surface
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Root.Theme.paddingNormal
                anchors.rightMargin: Root.Theme.paddingNormal
                spacing: 8

                // Back button
                Rectangle {
                    width: 32; height: 32
                    radius: Root.Theme.radiusSmall
                    color: backArea.containsMouse ? Root.Theme.surfaceContainerHigh : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "󰁍"
                        color: backArea.containsMouse ? Root.Theme.textPrimary : Root.Theme.textSecondary
                        font.family: Root.Theme.fontFamily
                        font.pixelSize: Root.Theme.fontSizeLarge
                    }

                    MouseArea {
                        id: backArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: wifiPanel.back()
                    }
                }

                Text {
                    text: "Wi-Fi"
                    color: Root.Theme.textPrimary
                    font.family: Root.Theme.fontFamily
                    font.pixelSize: Root.Theme.fontSizeLarge
                    font.weight: Font.DemiBold
                    Layout.fillWidth: true
                }

                // Refresh button
                Rectangle {
                    width: 32; height: 32
                    radius: Root.Theme.radiusSmall
                    color: refreshArea.containsMouse ? Root.Theme.surfaceContainerHigh : "transparent"
                    visible: wifiPanel.wifiEnabled

                    Text {
                        id: refreshIcon
                        anchors.centerIn: parent
                        text: "󰑐"
                        color: Root.Theme.textSecondary
                        font.family: Root.Theme.fontFamily
                        font.pixelSize: Root.Theme.fontSizeNormal
                    }

                    RotationAnimation {
                        target: refreshIcon
                        property: "rotation"
                        from: 0; to: 360
                        duration: 1000
                        loops: Animation.Infinite
                        running: wifiPanel.scanning
                    }

                    MouseArea {
                        id: refreshArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!wifiPanel.scanning && wifiPanel.wifiEnabled) {
                                wifiPanel.scanning = true;
                                wifiPanel.errorMessage = "";
                                rescanProc.running = true;
                            }
                        }
                    }
                }

                // Toggle switch
                Rectangle {
                    width: 44; height: 24; radius: 12
                    color: wifiPanel.wifiEnabled ? Root.Theme.primary : Root.Theme.surfaceContainerHigh
                    Behavior on color { ColorAnimation { duration: 200 } }

                    Rectangle {
                        width: 18; height: 18; radius: 9; y: 3
                        x: wifiPanel.wifiEnabled ? parent.width - width - 3 : 3
                        color: Root.Theme.textPrimary
                        Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: wifiPanel.toggleWifi()
                    }
                }
            }

            Rectangle {
                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                height: 1; color: Root.Theme.surfaceContainerHigh
            }
        }

        // ── Error ────────────────────────────────────────────────
        Text {
            visible: wifiPanel.errorMessage !== ""
            text: wifiPanel.errorMessage
            font.family: Root.Theme.fontFamily
            font.pixelSize: Root.Theme.fontSizeNormal
            color: Root.Theme.error
            Layout.fillWidth: true
            Layout.leftMargin: Root.Theme.paddingNormal
            Layout.rightMargin: Root.Theme.paddingNormal
            Layout.topMargin: Root.Theme.paddingNormal
            wrapMode: Text.Wrap
        }

        // ── States ───────────────────────────────────────────────
        Text {
            visible: !wifiPanel.wifiEnabled
            text: "Wi-Fi is disabled"
            font.family: Root.Theme.fontFamily
            font.pixelSize: Root.Theme.fontSizeNormal
            color: Root.Theme.textSecondary
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            Layout.topMargin: 40
        }

        Text {
            visible: wifiPanel.scanning && networkListModel.count === 0 && wifiPanel.wifiEnabled
            text: "Scanning..."
            font.family: Root.Theme.fontFamily
            font.pixelSize: Root.Theme.fontSizeNormal
            color: Root.Theme.textSecondary
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            Layout.topMargin: 40
        }

        Text {
            visible: wifiPanel.wifiEnabled && networkListModel.count === 0 && !wifiPanel.scanning
            text: "No networks found"
            font.family: Root.Theme.fontFamily
            font.pixelSize: Root.Theme.fontSizeNormal
            color: Root.Theme.textSecondary
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            Layout.topMargin: 40
        }

        // ── Network List ─────────────────────────────────────────
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: wifiPanel.wifiEnabled ? Root.Theme.paddingNormal : 0
            contentHeight: networkCol.implicitHeight
            clip: true
            boundsMovement: Flickable.StopAtBounds
            visible: wifiPanel.wifiEnabled

            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            ColumnLayout {
                id: networkCol
                width: parent.width
                spacing: 4

                Repeater {
                    model: networkListModel

                    delegate: Item {
                        required property int index
                        required property string ssid
                        required property int signal
                        required property string security
                        required property bool connected

                        Layout.fillWidth: true
                        width: networkCol.width
                        // Card height + optional password area
                        implicitHeight: networkCard.height + (showPass ? passwordBox.height + 4 : 0)

                        property bool showPass: wifiPanel.showConnect && wifiPanel.pendingSSID === ssid

                        Rectangle {
                            id: networkCard
                            width: parent.width - 2 * Root.Theme.paddingNormal
                            x: Root.Theme.paddingNormal
                            height: 52
                            radius: Root.Theme.radiusSmall
                            color: connected
                                ? Qt.rgba(Root.Theme.primaryContainer.r, Root.Theme.primaryContainer.g, Root.Theme.primaryContainer.b, 0.25)
                                : itemMA.containsMouse ? Root.Theme.surfaceContainerHigh : Root.Theme.surfaceContainer
                            border.width: connected || showPass ? 1 : 0
                            border.color: connected ? Root.Theme.primary : Root.Theme.primary

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Root.Theme.paddingNormal
                                anchors.rightMargin: Root.Theme.paddingNormal
                                spacing: Root.Theme.paddingNormal

                                Text {
                                    text: wifiPanel.signalIcon(signal)
                                    font.family: Root.Theme.fontFamily
                                    font.pixelSize: Root.Theme.fontSizeLarge
                                    color: connected ? Root.Theme.primary : Root.Theme.textSecondary
                                }

                                Text {
                                    text: ssid
                                    font.family: Root.Theme.fontFamily
                                    font.pixelSize: Root.Theme.fontSizeNormal
                                    color: connected ? Root.Theme.textPrimary : Root.Theme.textSecondary
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: signal + "%"
                                    font.family: Root.Theme.fontFamily
                                    font.pixelSize: Root.Theme.fontSizeXS
                                    color: Root.Theme.textSecondary
                                }

                                Text {
                                    visible: security !== ""
                                    text: "󰌾"
                                    font.family: Root.Theme.fontFamily
                                    font.pixelSize: Root.Theme.fontSizeNormal
                                    color: Root.Theme.textSecondary
                                }

                                Rectangle {
                                    visible: connected
                                    implicitWidth: connLbl.implicitWidth + 12
                                    implicitHeight: 20
                                    radius: 10
                                    color: Root.Theme.primary
                                    Text {
                                        id: connLbl
                                        anchors.centerIn: parent
                                        text: "Connected"
                                        font.family: Root.Theme.fontFamily
                                        font.pixelSize: Root.Theme.fontSizeXS
                                        color: Root.Theme.tileActiveText
                                    }
                                }
                            }

                            MouseArea {
                                id: itemMA
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (connected) return;
                                    if (wifiPanel.pendingSSID === ssid) {
                                        // Toggle off
                                        wifiPanel.showConnect = false;
                                        wifiPanel.pendingSSID = "";
                                    } else {
                                        wifiPanel.showConnect = true;
                                        wifiPanel.pendingSSID = ssid;
                                        wifiPanel.pendingSecurity = security;
                                        wifiPanel.errorMessage = "";
                                        passwordField.text = "";
                                        passwordField.forceActiveFocus();
                                    }
                                }
                            }
                        }

                        // ── Inline password input ────────────────
                        Rectangle {
                            id: passwordBox
                            visible: showPass
                            x: Root.Theme.paddingNormal
                            y: networkCard.height + 4
                            width: parent.width - 2 * Root.Theme.paddingNormal
                            height: 88
                            radius: Root.Theme.radiusSmall
                            color: Root.Theme.surfaceContainerHigh
                            border.width: 1
                            border.color: Root.Theme.primary

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: Root.Theme.paddingNormal
                                spacing: 8

                                // Password field
                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 34
                                    radius: Root.Theme.radiusSmall
                                    color: Root.Theme.surfaceContainerHigh
                                    border.width: passwordField.activeFocus ? 1 : 0
                                    border.color: Root.Theme.primary

                                    TextField {
                                        id: passwordField
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10
                                        placeholderText: security !== "" ? "Password" : "No password required for saved networks"
                                        placeholderTextColor: Qt.rgba(Root.Theme.textSecondary.r, Root.Theme.textSecondary.g, Root.Theme.textSecondary.b, 0.5)
                                        color: Root.Theme.textPrimary
                                        echoMode: TextInput.Password
                                        font.family: Root.Theme.fontFamily
                                        font.pixelSize: Root.Theme.fontSizeNormal
                                        background: Item {}
                                        onAccepted: {
                                            wifiPanel.connectToNetwork(wifiPanel.pendingSSID, text);
                                        }
                                    }
                                }

                                // Buttons
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    // Cancel
                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 28
                                        radius: Root.Theme.radiusSmall
                                        color: cancelBtnMA.containsMouse ? Root.Theme.surfaceContainerHigh : "transparent"
                                        border.width: 1
                                        border.color: Root.Theme.surfaceContainerHigh

                                        Text {
                                            anchors.centerIn: parent
                                            text: "Cancel"
                                            font.family: Root.Theme.fontFamily
                                            font.pixelSize: Root.Theme.fontSizeNormal
                                            color: Root.Theme.textSecondary
                                        }

                                        MouseArea {
                                            id: cancelBtnMA
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                wifiPanel.showConnect = false;
                                                wifiPanel.pendingSSID = "";
                                            }
                                        }
                                    }

                                    // Connect
                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 28
                                        radius: Root.Theme.radiusSmall
                                        color: connectBtnMA.containsMouse
                                            ? Qt.lighter(Root.Theme.primary, 1.2)
                                            : Root.Theme.primary

                                        Text {
                                            anchors.centerIn: parent
                                        text: "Connect"
                                        font.family: Root.Theme.fontFamily
                                        font.pixelSize: Root.Theme.fontSizeNormal
                                        color: Root.Theme.tileActiveText
                                            font.weight: Font.DemiBold
                                        }

                                        MouseArea {
                                            id: connectBtnMA
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                wifiPanel.connectToNetwork(wifiPanel.pendingSSID, passwordField.text);
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Bottom spacer
                Item { Layout.fillWidth: true; height: Root.Theme.paddingNormal }
            }
        }

        // Spacer — ensures content stacks from top when no fillHeight child is visible
        Item { Layout.fillHeight: true }
    }
}
