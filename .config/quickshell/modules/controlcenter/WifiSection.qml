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

    // Set by the parent while this page is the visible one.
    property bool pageActive: false

    property bool wifiEnabled: true
    property bool scanning: false
    property string errorMessage: ""

    // Wifi device name (e.g. "wlan0"), filled in by the profile dump.
    property string wifiDevice: ""
    // UUID of the profile that is currently active.
    property string activeUuid: ""

    // Inline password input state
    property string pendingSSID: ""
    property string pendingSecurity: ""
    property bool showConnect: false

    // Raw data, merged into networkListModel whenever either source changes.
    property var scanResults: []
    property var savedProfiles: []

    // Activation state, kept across retries.
    property int activateAttempts: 0
    property string activateUuid: ""
    property var activateCommand: []


    // ── Processes ────────────────────────────────────────────────

    Process {
        id: radioStatusProc
        command: ["nmcli", "radio", "wifi"]
        stdout: StdioCollector {
            onStreamFinished: {
                var wasEnabled = wifiPanel.wifiEnabled;
                wifiPanel.wifiEnabled = (text.trim() === "enabled");
                if (wifiPanel.wifiEnabled && !wasEnabled) {
                    wifiPanel.startScan();
                }
                if (!wifiPanel.wifiEnabled) {
                    wifiPanel.scanning = false;
                }
            }
        }
    }

    // Scan results as reported by the backend (cached, does not trigger a scan).
    Process {
        id: listNetworksProc
        command: ["nmcli", "-t", "-f", "SSID,SIGNAL,SECURITY,IN-USE", "dev", "wifi", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                wifiPanel.scanning = false;
                wifiPanel.parseScanned(text);
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                wifiPanel.scanning = false;
                wifiPanel.errorMessage = "Failed to scan (code " + exitCode + ")";
            }
        }
    }

    // Saved connection profiles (uuid / ssid / autoconnect / priority / iface).
    Process {
        id: listProfilesProc
        command: ["/bin/sh", "-c", "~/.config/quickshell/scripts/wifi-networks.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                wifiPanel.parseProfiles(text);
            }
        }
    }

    Process {
        id: toggleWifiProc
        stdout: StdioCollector {}
        onExited: (exitCode, exitStatus) => {
            radioStatusProc.running = true;
            listProfilesProc.running = true;
        }
    }

    // Activation, for both saved profiles and networks without one.
    //
    // iwd needs a moment to finish tearing down the previous connection
    // before it accepts a new one. NetworkManager does not wait and reports
    // the race as "no-secrets" / "Operation failed", so retry once.
    Process {
        id: activateProc
        stdout: StdioCollector {}
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                if (wifiPanel.activateAttempts < 1) {
                    wifiPanel.activateAttempts++;
                    activateRetryTimer.start();
                    return;
                }
                wifiPanel.errorMessage = "Connection failed";
            } else {
                wifiPanel.errorMessage = "";
                wifiPanel.showConnect = false;
                wifiPanel.pendingSSID = "";
            }
            wifiPanel.refresh();
        }
    }

    Timer {
        id: activateRetryTimer
        interval: 1500
        repeat: false
        onTriggered: { wifiPanel.runActivation(); }
    }

    Process {
        id: disconnectProc
        stdout: StdioCollector {}
        onExited: (exitCode, exitStatus) => {
            wifiPanel.errorMessage = "";
            wifiPanel.showConnect = false;
            wifiPanel.pendingSSID = "";
            wifiPanel.refresh();
        }
    }

    Process {
        id: forgetProc
        stdout: StdioCollector {}
        onExited: (exitCode, exitStatus) => {
            wifiPanel.errorMessage = "";
            wifiPanel.showConnect = false;
            wifiPanel.pendingSSID = "";
            wifiPanel.refresh();
        }
    }

    Process {
        id: rescanProc
        command: ["nmcli", "dev", "wifi", "rescan"]
        stdout: StdioCollector {}
        // Ignore the exit code: a busy backend rejects the request, but the
        // list that follows is still worth showing.
        onExited: (exitCode, exitStatus) => { rescanWaitTimer.start(); }
    }

    Timer {
        id: rescanWaitTimer
        interval: 3500
        repeat: false
        onTriggered: { listNetworksProc.running = true; }
    }

    // Cheap refresh — re-reads the cached scan list.
    Timer {
        id: refreshTimer
        interval: 10000
        running: wifiPanel.pageActive && wifiPanel.wifiEnabled
        repeat: true
        onTriggered: {
            if (!wifiPanel.scanning) {
                wifiPanel.scanning = true;
                listNetworksProc.running = true;
            }
        }
    }

    // Real scan — the cached list is frozen between rescans, so without this
    // the panel keeps showing whatever was found at boot.
    Timer {
        id: rescanTimer
        interval: 30000
        running: wifiPanel.pageActive && wifiPanel.wifiEnabled
        repeat: true
        onTriggered: { wifiPanel.startScan(); }
    }

    Component.onCompleted: {
        radioStatusProc.running = true;
        listProfilesProc.running = true;
        scanning = true;
        listNetworksProc.running = true;
        // pageActive may already be true here, in which case
        // onPageActiveChanged never fires.
        if (pageActive) startScan();
    }

    onPageActiveChanged: {
        if (pageActive) {
            radioStatusProc.running = true;
            listProfilesProc.running = true;
            startScan();
        }
    }

    // ── Logic ────────────────────────────────────────────────────

    function startScan() {
        if (!wifiEnabled) return;
        scanning = true;
        errorMessage = "";
        rescanProc.running = true;
    }

    function refresh() {
        listProfilesProc.running = true;
        listNetworksProc.running = true;
    }

    // nmcli terse output escapes ':' as '\:'.
    function unescapeNm(value) {
        return value.replace(/\\:/g, ":").replace(/\\\\/g, "\\");
    }

    function parseScanned(output) {
        var lines = output.trim().split("\n");
        var results = [];
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
            var ssid = unescapeNm(rest.substring(0, sigColon).trim());

            if (isNaN(signal)) signal = 0;
            if (ssid === "") continue;

            if (seen[ssid] !== undefined) {
                var idx = seen[ssid];
                if (results[idx].signal < signal) {
                    results[idx].signal = signal;
                    results[idx].security = security;
                }
                if (inUse === "*") results[idx].inUse = true;
                continue;
            }

            seen[ssid] = results.length;
            results.push({ ssid: ssid, signal: signal, security: security, inUse: inUse === "*" });
        }

        scanResults = results;
        rebuildModel();
    }

    function parseProfiles(output) {
        var lines = output.trim().split("\n");
        var profiles = [];
        var active = "";

        for (var i = 0; i < lines.length; i++) {
            var line = lines[i];
            if (line === "") continue;

            var parts = line.split("\t");
            if (parts[0] === "DEV") {
                wifiDevice = parts.length > 1 ? parts[1] : "";
                continue;
            }
            if (parts[0] === "ACTIVE") {
                active = parts.length > 1 ? parts[1] : "";
                continue;
            }
            if (parts[0] !== "CON") continue;

            profiles.push({
                uuid: parts.length > 1 ? parts[1] : "",
                ssid: parts.length > 2 ? parts[2] : "",
                autoconnect: parts.length > 3 ? parts[3] : "no",
                priority: parseInt(parts.length > 4 ? parts[4] : "0") || 0,
                iface: parts.length > 5 ? parts[5] : "",
                keyMgmt: parts.length > 6 ? parts[6] : ""
            });
        }

        savedProfiles = profiles;
        activeUuid = active;
        rebuildModel();
    }

    // A profile pinned to an interface that does not exist here can never be
    // activated, so unpinned profiles win over pinned ones for the same SSID.
    function profileScore(profile) {
        var usable = (profile.iface === "" || profile.iface === wifiDevice) ? 1000 : 0;
        return usable + profile.priority;
    }

    function rebuildModel() {
        var merged = {};
        var order = [];

        // Saved profiles first: they stay usable even when the AP is missing
        // from the current scan results.
        for (var i = 0; i < savedProfiles.length; i++) {
            var p = savedProfiles[i];
            if (!p.ssid) continue;

            var entry = merged[p.ssid];
            if (!entry) {
                entry = {
                    ssid: p.ssid,
                    signal: 0,
                    security: p.keyMgmt ? "WPA2" : "",
                    connected: p.uuid === activeUuid,
                    saved: true,
                    uuid: p.uuid,
                    score: profileScore(p)
                };
                merged[p.ssid] = entry;
                order.push(p.ssid);
            } else {
                if (p.uuid === activeUuid) entry.connected = true;
                var score = profileScore(p);
                if (score > entry.score) {
                    entry.uuid = p.uuid;
                    entry.score = score;
                }
            }
        }

        // Then whatever the radio is currently seeing.
        for (var j = 0; j < scanResults.length; j++) {
            var n = scanResults[j];
            if (!n.ssid) continue;

            var known = merged[n.ssid];
            if (known) {
                known.signal = n.signal;
                if (n.security) known.security = n.security;
                if (n.inUse) known.connected = true;
            } else {
                merged[n.ssid] = {
                    ssid: n.ssid,
                    signal: n.signal,
                    security: n.security,
                    connected: n.inUse,
                    saved: false,
                    uuid: "",
                    score: 0
                };
                order.push(n.ssid);
            }
        }

        var rows = [];
        for (var k = 0; k < order.length; k++) rows.push(merged[order[k]]);

        rows.sort(function(a, b) {
            if (a.connected && !b.connected) return -1;
            if (!a.connected && b.connected) return 1;
            if (a.saved && !b.saved) return -1;
            if (!a.saved && b.saved) return 1;
            return b.signal - a.signal;
        });

        networkListModel.clear();
        for (var m = 0; m < rows.length; m++) {
            var r = rows[m];
            networkListModel.append({
                ssid: r.ssid,
                signal: r.signal,
                security: r.security,
                connected: r.connected,
                saved: r.saved,
                uuid: r.uuid
            });
        }
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
            activateCommand = ["nmcli", "dev", "wifi", "connect", ssid, "password", password];
        } else {
            activateCommand = ["nmcli", "dev", "wifi", "connect", ssid];
        }
        activateAttempts = 0;
        runActivation();
    }

    function activateProfile(uuid) {
        activateUuid = uuid;
        activateCommand = ["nmcli", "connection", "up", uuid];
        activateAttempts = 0;
        runActivation();
    }

    function runActivation() {
        activateProc.command = activateCommand;
        activateProc.running = true;
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
                            if (wifiPanel.wifiEnabled) {
                                wifiPanel.scanning = true;
                                wifiPanel.errorMessage = "";
                                wifiPanel.startScan();
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
                        required property bool saved
                        required property string uuid

                        Layout.fillWidth: true
                        width: networkCol.width
                        // Card height + optional detail area
                        implicitHeight: networkCard.height + (showDetail ? detailBox.height + 4 : 0)

                        property bool showDetail: wifiPanel.showConnect && wifiPanel.pendingSSID === ssid

                        Rectangle {
                            id: networkCard
                            width: parent.width - 2 * Root.Theme.paddingNormal
                            x: Root.Theme.paddingNormal
                            height: 52
                            radius: Root.Theme.radiusSmall
                            color: connected
                                ? Qt.rgba(Root.Theme.primaryContainer.r, Root.Theme.primaryContainer.g, Root.Theme.primaryContainer.b, 0.25)
                                : itemMA.containsMouse ? Root.Theme.surfaceContainerHigh : Root.Theme.surfaceContainer
                            border.width: connected || showDetail ? 1 : 0
                            border.color: Root.Theme.primary

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

                                // Saved badge — the profile exists, so it can be
                                // activated without retyping the passphrase.
                                Rectangle {
                                    visible: saved && !connected
                                    implicitWidth: savedLbl.implicitWidth + 12
                                    implicitHeight: 20
                                    radius: 10
                                    color: Root.Theme.surfaceContainerHigh

                                    Text {
                                        id: savedLbl
                                        anchors.centerIn: parent
                                        text: "Saved"
                                        font.family: Root.Theme.fontFamily
                                        font.pixelSize: Root.Theme.fontSizeXS
                                        color: Root.Theme.textSecondary
                                    }
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
                                    if (wifiPanel.pendingSSID === ssid) {
                                        wifiPanel.showConnect = false;
                                        wifiPanel.pendingSSID = "";
                                    } else {
                                        wifiPanel.showConnect = true;
                                        wifiPanel.pendingSSID = ssid;
                                        wifiPanel.pendingSecurity = security;
                                        wifiPanel.errorMessage = "";
                                        passwordField.text = "";
                                        if (!connected && !saved) passwordField.forceActiveFocus();
                                    }
                                }
                            }
                        }

                        // ── Inline detail area ────────────────
                        Rectangle {
                            id: detailBox
                            visible: showDetail
                            x: Root.Theme.paddingNormal
                            y: networkCard.height + 4
                            width: parent.width - 2 * Root.Theme.paddingNormal
                            height: connected ? 96 : (saved ? 68 : 96)
                            radius: Root.Theme.radiusSmall
                            color: Root.Theme.surfaceContainerHigh
                            border.width: 1
                            border.color: Root.Theme.primary

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: Root.Theme.paddingNormal
                                spacing: 8

                                // Connected: show disclaimer
                                Text {
                                    visible: connected
                                    Layout.fillWidth: true
                                    text: "Connected to " + ssid
                                    font.family: Root.Theme.fontFamily
                                    font.pixelSize: Root.Theme.fontSizeNormal
                                    color: Root.Theme.textSecondary
                                    horizontalAlignment: Text.AlignHCenter
                                }

                                // Saved but not connected: no passphrase needed
                                Text {
                                    visible: !connected && saved
                                    Layout.fillWidth: true
                                    text: "Saved network — connect without re-entering the password"
                                    font.family: Root.Theme.fontFamily
                                    font.pixelSize: Root.Theme.fontSizeNormal
                                    color: Root.Theme.textSecondary
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.Wrap
                                }

                                // Not saved: password field
                                Rectangle {
                                    visible: !connected && !saved
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

                                // Forget / Connect / Disconnect buttons
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Rectangle {
                                        visible: connected
                                        Layout.fillWidth: true
                                        height: 28
                                        radius: Root.Theme.radiusSmall
                                        color: "transparent"
                                        border.width: 1
                                        border.color: forgetBtnMA.containsMouse ? Root.Theme.error : Root.Theme.surfaceContainerHigh

                                        Text {
                                            anchors.centerIn: parent
                                            text: "Forget"
                                            font.family: Root.Theme.fontFamily
                                            font.pixelSize: Root.Theme.fontSizeNormal
                                            color: forgetBtnMA.containsMouse ? Root.Theme.error : Root.Theme.textSecondary
                                        }

                                        MouseArea {
                                            id: forgetBtnMA
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                forgetProc.command = ["nmcli", "connection", "delete", uuid];
                                                forgetProc.running = true;
                                            }
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 28
                                        radius: Root.Theme.radiusSmall
                                        color: {
                                            if (connected) {
                                                return actionBtnMA.containsMouse
                                                    ? Qt.lighter(Root.Theme.error, 1.2)
                                                    : Root.Theme.error
                                            }
                                            return actionBtnMA.containsMouse
                                                ? Qt.lighter(Root.Theme.primary, 1.2)
                                                : Root.Theme.primary
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            text: connected ? "Disconnect" : "Connect"
                                            font.family: Root.Theme.fontFamily
                                            font.pixelSize: Root.Theme.fontSizeNormal
                                            color: Root.Theme.tileActiveText
                                            font.weight: Font.DemiBold
                                        }

                                        MouseArea {
                                            id: actionBtnMA
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (connected) {
                                                    disconnectProc.command = ["nmcli", "connection", "down", uuid];
                                                    disconnectProc.running = true;
                                                } else if (saved) {
                                                    wifiPanel.activateProfile(uuid);
                                                } else {
                                                    wifiPanel.connectToNetwork(wifiPanel.pendingSSID, passwordField.text);
                                                }
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
