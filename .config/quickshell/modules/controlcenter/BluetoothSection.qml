import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Io
import "../.." as Root

// Bluetooth Sub-Page — full-height panel for Bluetooth management
// Parent navigates here via currentPage = "bluetooth"; back() signal returns to main
Item {
    id: bt

    signal back()

    property bool enabled: true
    property bool scanning: false
    property string error: ""
    property bool discoveryScanning: false
    property string pairStatus: ""
    property string pairingMAC: ""
    property string allDevicesText: ""


    // ── Processes ────────────────────────────────────────────────

    Process {
        id: powerProc
        command: ["bluetoothctl", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                var wasEnabled = bt.enabled;
                bt.enabled = text.includes("Powered: yes");
                if (bt.enabled && !wasEnabled) listProc.running = true;
                if (!bt.enabled) pairedModel.clear();
            }
        }
    }

    Process {
        id: listProc
        command: ["bluetoothctl", "devices", "Paired"]
        stdout: StdioCollector {
            onStreamFinished: {
                bt.scanning = false;
                var lines = text.trim().split("\n");
                pairedModel.clear();
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim();
                    if (line === "") continue;
                    var parts = line.split(" ");
                    if (parts.length >= 3 && parts[0] === "Device") {
                        pairedModel.append({ mac: parts[1], name: parts.slice(2).join(" "), connected: false });
                        checkConn(parts[1]);
                    }
                }
                bt.error = "";
            }
        }
        onExited: (code, status) => { if (code !== 0) { bt.scanning = false; bt.error = "Failed to list"; } }
    }

    Process {
        id: toggleProc
        stdout: StdioCollector {}
        onExited: (code, status) => { powerProc.running = true; }
    }

    Process {
        id: connProc
        stdout: StdioCollector {}
        onExited: (code, status) => { bt.error = code !== 0 ? "Failed" : ""; listProc.running = true; }
    }

    Process {
        id: disconnProc
        stdout: StdioCollector {}
        onExited: (code, status) => { bt.error = code !== 0 ? "Failed" : ""; listProc.running = true; }
    }

    Process {
        id: scanOnProc
        command: ["bluetoothctl", "scan", "on"]
        stdout: StdioCollector {}
    }

    Process {
        id: scanOffProc
        command: ["bluetoothctl", "scan", "off"]
        stdout: StdioCollector {}
        onExited: (code, status) => { allDevicesProc.running = true; }
    }

    Process {
        id: allDevicesProc
        command: ["bluetoothctl", "devices"]
        stdout: StdioCollector {
            onStreamFinished: {
                bt.allDevicesText = text;
                pairedDevicesForDiffProc.running = true;
            }
        }
    }

    Process {
        id: pairedDevicesForDiffProc
        command: ["bluetoothctl", "devices", "Paired"]
        stdout: StdioCollector {
            onStreamFinished: {
                bt.parseUnpairedDevices(bt.allDevicesText, text);
                bt.discoveryScanning = false;
            }
        }
    }

    Process {
        id: pairProc
        stdout: StdioCollector {}
        onExited: (code, status) => {
            if (code !== 0) { bt.pairStatus = "Pairing failed"; bt.pairingMAC = ""; pairStatusTimer.running = true; }
            else { bt.pairStatus = "Trusting..."; trustProc.command = ["bluetoothctl", "trust", bt.pairingMAC]; trustProc.running = true; }
        }
    }

    Process {
        id: trustProc
        stdout: StdioCollector {}
        onExited: (code, status) => {
            if (code !== 0) { bt.pairStatus = "Trust failed"; bt.pairingMAC = ""; pairStatusTimer.running = true; }
            else { bt.pairStatus = "Connecting..."; pairConnProc.command = ["bluetoothctl", "connect", bt.pairingMAC]; pairConnProc.running = true; }
        }
    }

    Process {
        id: pairConnProc
        stdout: StdioCollector {}
        onExited: (code, status) => {
            bt.pairStatus = code !== 0 ? "Paired (connect failed)" : "Paired successfully";
            bt.pairingMAC = "";
            listProc.running = true;
            pairStatusTimer.running = true;
        }
    }

    Process {
        id: checkProc
        property string targetMAC: ""
        stdout: StdioCollector {
            onStreamFinished: {
                for (var i = 0; i < pairedModel.count; i++) {
                    if (pairedModel.get(i).mac === checkProc.targetMAC) {
                        pairedModel.setProperty(i, "connected", text.includes("Connected: yes"));
                        break;
                    }
                }
            }
        }
    }

    Timer {
        interval: 5000
        running: bt.visible && bt.enabled
        repeat: true
        onTriggered: { if (!bt.scanning) { bt.scanning = true; listProc.running = true; } }
    }

    Timer {
        id: scanTimer
        interval: 5000
        running: false
        repeat: false
        onTriggered: { scanOnProc.running = false; scanOffProc.running = true; }
    }

    Timer {
        id: pairStatusTimer
        interval: 3000
        running: false
        repeat: false
        onTriggered: bt.pairStatus = ""
    }

    Component.onCompleted: { powerProc.running = true; bt.scanning = true; listProc.running = true; }

    function checkConn(mac) {
        checkProc.targetMAC = mac;
        checkProc.command = ["bluetoothctl", "info", mac];
        checkProc.running = true;
    }

    function startDiscovery() {
        if (bt.discoveryScanning || !bt.enabled) return;
        bt.discoveryScanning = true;
        bt.pairStatus = "";
        unpairedModel.clear();
        scanOnProc.running = true;
        scanTimer.running = true;
    }

    function pairDevice(mac) {
        if (bt.pairingMAC !== "") return;
        bt.pairingMAC = mac;
        bt.pairStatus = "Pairing...";
        pairProc.command = ["bluetoothctl", "pair", mac];
        pairProc.running = true;
    }

    function parseUnpairedDevices(allText, pairedText) {
        var pairedMACs = {};
        var pairedLines = pairedText.trim().split("\n");
        for (var i = 0; i < pairedLines.length; i++) {
            var line = pairedLines[i].trim();
            if (line === "") continue;
            var parts = line.split(" ");
            if (parts.length >= 2 && parts[0] === "Device") pairedMACs[parts[1]] = true;
        }
        unpairedModel.clear();
        var allLines = allText.trim().split("\n");
        for (var j = 0; j < allLines.length; j++) {
            var aline = allLines[j].trim();
            if (aline === "") continue;
            var aparts = aline.split(" ");
            if (aparts.length >= 3 && aparts[0] === "Device") {
                if (!pairedMACs[aparts[1]]) {
                    unpairedModel.append({ mac: aparts[1], name: aparts.slice(2).join(" ") });
                }
            }
        }
    }

    ListModel { id: pairedModel }
    ListModel { id: unpairedModel }

    // ── UI ───────────────────────────────────────────────────────────

    ColumnLayout {
        anchors.fill: parent
        spacing: 0


        // ── Header ──────────────────────────────────────────────────
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
                anchors.leftMargin: 12
                anchors.rightMargin: 14
                spacing: 8

                // Back button (circular)
                Rectangle {
                    width: 34; height: 34
                    radius: 17
                    color: btBackArea.containsMouse ? Root.Theme.surfaceContainerHigh : Qt.rgba(Root.Theme.surfaceContainerHigh.r, Root.Theme.surfaceContainerHigh.g, Root.Theme.surfaceContainerHigh.b, 0.4)
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        text: "\u{f0141}"
                        color: btBackArea.containsMouse ? Root.Theme.textPrimary : Root.Theme.textSecondary
                        font.family: Root.Theme.fontFamily
                        font.pixelSize: 16
                    }

                    MouseArea {
                        id: btBackArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: bt.back()
                    }
                }

                Text {
                    text: "Bluetooth"
                    color: Root.Theme.textPrimary
                    font.family: Root.Theme.fontFamily
                    font.pixelSize: Root.Theme.fontSizeLarge
                    font.weight: Font.DemiBold
                    Layout.fillWidth: true
                }

                // Scan button (circular)
                Rectangle {
                    visible: bt.enabled
                    width: 34; height: 34
                    radius: 17
                    color: scanBtnMA.containsMouse ? Root.Theme.surfaceContainerHigh : Qt.rgba(Root.Theme.surfaceContainerHigh.r, Root.Theme.surfaceContainerHigh.g, Root.Theme.surfaceContainerHigh.b, 0.4)
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        id: scanBtnIcon
                        anchors.centerIn: parent
                        text: "\u{f0450}"
                        font.family: Root.Theme.fontFamily
                        font.pixelSize: 14
                        color: bt.discoveryScanning ? Root.Theme.primary : Root.Theme.textSecondary
                    }

                    RotationAnimation {
                        target: scanBtnIcon
                        property: "rotation"
                        from: 0; to: 360
                        duration: 1000
                        loops: Animation.Infinite
                        running: bt.discoveryScanning
                    }

                    MouseArea {
                        id: scanBtnMA
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: bt.startDiscovery()
                    }
                }

                // Toggle switch
                Rectangle {
                    width: 44; height: 24; radius: 12
                    color: bt.enabled ? Root.Theme.primary : Root.Theme.surfaceContainerHigh
                    border.width: 1
                    border.color: bt.enabled ? Root.Theme.primary : Root.Theme.surfaceContainerHigh
                    Behavior on color { ColorAnimation { duration: 200 } }

                    Rectangle {
                        width: 18; height: 18; radius: 9; y: 3
                        x: bt.enabled ? parent.width - width - 3 : 3
                        color: Root.Theme.textPrimary
                        Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            toggleProc.command = bt.enabled ? ["bluetoothctl", "power", "off"] : ["bluetoothctl", "power", "on"];
                            toggleProc.running = true;
                        }
                    }
                }
            }

            // Bottom border
            Rectangle {
                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                height: 1; color: Root.Theme.surfaceContainerHigh
            }
        }

        // ── Disabled state ─────────────────────────────────────────
        ColumnLayout {
            visible: !bt.enabled
            Layout.fillWidth: true
            Layout.topMargin: 60
            spacing: 12

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: 56; height: 56; radius: 28
                color: Qt.rgba(Root.Theme.textSecondary.r, Root.Theme.textSecondary.g, Root.Theme.textSecondary.b, 0.1)

                Text {
                    anchors.centerIn: parent
                    text: "\u{f00b2}"
                    font.family: Root.Theme.fontFamily
                    font.pixelSize: 24
                    color: Root.Theme.textSecondary
                    opacity: 0.5
                }
            }

            Text {
                text: "Bluetooth is off"
                font.family: Root.Theme.fontFamily
                font.pixelSize: Root.Theme.fontSizeNormal
                color: Root.Theme.textSecondary
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
            }

            Text {
                text: "Turn on to connect to devices"
                font.family: Root.Theme.fontFamily
                font.pixelSize: Root.Theme.fontSizeXS
                color: Qt.rgba(Root.Theme.textSecondary.r, Root.Theme.textSecondary.g, Root.Theme.textSecondary.b, 0.6)
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
            }
        }

        // ── Error ───────────────────────────────────────────────────
        Rectangle {
            visible: bt.error !== "" && bt.enabled
            Layout.fillWidth: true
            Layout.leftMargin: Root.Theme.paddingNormal
            Layout.rightMargin: Root.Theme.paddingNormal
            Layout.topMargin: Root.Theme.paddingNormal
            implicitHeight: errText.implicitHeight + 16
            radius: Root.Theme.radiusSmall
            color: Qt.rgba(1, 0.42, 0.42, 0.1)
            border.width: 1
            border.color: Qt.rgba(1, 0.42, 0.42, 0.25)

            Text {
                id: errText
                anchors.centerIn: parent
                text: bt.error
                font.family: Root.Theme.fontFamily
                font.pixelSize: Root.Theme.fontSizeSmall
                color: Root.Theme.error
                wrapMode: Text.Wrap
                width: parent.width - 16
                horizontalAlignment: Text.AlignHCenter
            }
        }

        // ── Scanning placeholder ────────────────────────────────────
        ColumnLayout {
            visible: bt.scanning && pairedModel.count === 0 && bt.enabled
            Layout.fillWidth: true
            Layout.topMargin: 60
            spacing: 12

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: 56; height: 56; radius: 28
                color: Qt.rgba(Root.Theme.primary.r, Root.Theme.primary.g, Root.Theme.primary.b, 0.1)

                Text {
                    id: scanPlaceholderIcon
                    anchors.centerIn: parent
                    text: "\u{f0450}"
                    font.family: Root.Theme.fontFamily
                    font.pixelSize: 24
                    color: Root.Theme.primary
                    opacity: 0.7
                }

                RotationAnimation {
                    target: scanPlaceholderIcon
                    property: "rotation"
                    from: 0; to: 360
                    duration: 1200
                    loops: Animation.Infinite
                    running: bt.scanning && pairedModel.count === 0 && bt.enabled
                }
            }

            Text {
                text: "Scanning..."
                font.family: Root.Theme.fontFamily
                font.pixelSize: Root.Theme.fontSizeNormal
                color: Root.Theme.textSecondary
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
            }
        }

        // ── No paired devices ───────────────────────────────────────
        ColumnLayout {
            visible: bt.enabled && pairedModel.count === 0 && !bt.scanning
            Layout.fillWidth: true
            Layout.topMargin: 60
            spacing: 12

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: 56; height: 56; radius: 28
                color: Qt.rgba(Root.Theme.textSecondary.r, Root.Theme.textSecondary.g, Root.Theme.textSecondary.b, 0.1)

                Text {
                    anchors.centerIn: parent
                    text: "\u{f00af}"
                    font.family: Root.Theme.fontFamily
                    font.pixelSize: 24
                    color: Root.Theme.textSecondary
                    opacity: 0.5
                }
            }

            Text {
                text: "No paired devices"
                font.family: Root.Theme.fontFamily
                font.pixelSize: Root.Theme.fontSizeNormal
                color: Root.Theme.textSecondary
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
            }

            Text {
                text: "Tap scan to find nearby devices"
                font.family: Root.Theme.fontFamily
                font.pixelSize: Root.Theme.fontSizeXS
                color: Qt.rgba(Root.Theme.textSecondary.r, Root.Theme.textSecondary.g, Root.Theme.textSecondary.b, 0.6)
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
            }
        }

        // ── Device Lists ─────────────────────────────────────────────
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: 8
            contentHeight: devicesCol.implicitHeight
            clip: true
            boundsMovement: Flickable.StopAtBounds
            visible: bt.enabled && (pairedModel.count > 0 || unpairedModel.count > 0)

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                contentItem: Rectangle {
                    implicitWidth: 3
                    radius: 1.5
                    color: Root.Theme.textSecondary
                    opacity: 0.3
                }
            }

            ColumnLayout {
                id: devicesCol
                width: parent.width
                spacing: 6

                // ── Paired Devices section ──────────────────────────
                Text {
                    visible: pairedModel.count > 0
                    text: "PAIRED DEVICES"
                    font.family: Root.Theme.fontFamily
                    font.pixelSize: Root.Theme.fontSizeXS
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1
                    color: Qt.rgba(Root.Theme.textSecondary.r, Root.Theme.textSecondary.g, Root.Theme.textSecondary.b, 0.6)
                    Layout.fillWidth: true
                    Layout.leftMargin: Root.Theme.paddingNormal + 4
                    Layout.rightMargin: Root.Theme.paddingNormal
                    Layout.topMargin: 4
                    Layout.bottomMargin: 2
                }

                Repeater {
                    model: pairedModel

                    delegate: Rectangle {
                        required property int index
                        required property string mac
                        required property string name
                        required property bool connected

                        Layout.fillWidth: true
                        Layout.leftMargin: Root.Theme.paddingNormal
                        Layout.rightMargin: Root.Theme.paddingNormal
                        implicitHeight: 56
                        radius: Root.Theme.radiusSmall
                        color: dma.containsMouse
                            ? (connected
                                ? Qt.rgba(Root.Theme.primaryContainer.r, Root.Theme.primaryContainer.g, Root.Theme.primaryContainer.b, 0.25)
                                : Root.Theme.surfaceContainerHigh)
                            : (connected
                                ? Qt.rgba(Root.Theme.primaryContainer.r, Root.Theme.primaryContainer.g, Root.Theme.primaryContainer.b, 0.15)
                                : Root.Theme.surfaceContainer)
                        border.width: 1
                        border.color: connected
                            ? Qt.rgba(Root.Theme.primary.r, Root.Theme.primary.g, Root.Theme.primary.b, 0.3)
                            : Qt.rgba(Root.Theme.surfaceContainerHigh.r, Root.Theme.surfaceContainerHigh.g, Root.Theme.surfaceContainerHigh.b, 0.5)

                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 10

                            // Icon circle
                            Rectangle {
                                Layout.preferredWidth: 34
                                Layout.preferredHeight: 34
                                radius: 17
                                color: connected
                                    ? Root.Theme.primary
                                    : Qt.rgba(Root.Theme.textSecondary.r, Root.Theme.textSecondary.g, Root.Theme.textSecondary.b, 0.12)
                                Behavior on color { ColorAnimation { duration: 200 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "\u{f00af}"
                                    font.family: Root.Theme.fontFamily
                                    font.pixelSize: 15
                                    color: connected ? Root.Theme.tileActiveText : Root.Theme.textSecondary
                                }
                            }

                            // Name + status
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                Text {
                                    text: name
                                    font.family: Root.Theme.fontFamily
                                    font.pixelSize: Root.Theme.fontSizeNormal
                                    font.weight: Font.Medium
                                    color: connected ? Root.Theme.textPrimary : Root.Theme.textSecondary
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: connected ? "Connected" : "Not connected"
                                    font.family: Root.Theme.fontFamily
                                    font.pixelSize: Root.Theme.fontSizeXS
                                    color: connected
                                        ? Qt.rgba(Root.Theme.primary.r, Root.Theme.primary.g, Root.Theme.primary.b, 0.85)
                                        : Qt.rgba(Root.Theme.textSecondary.r, Root.Theme.textSecondary.g, Root.Theme.textSecondary.b, 0.5)
                                    Layout.fillWidth: true
                                }
                            }

                            // Action button
                            Rectangle {
                                implicitWidth: actionLbl.implicitWidth + 18
                                implicitHeight: 28
                                radius: 14
                                color: actionMA.containsMouse
                                    ? (connected ? Qt.rgba(1, 0.42, 0.42, 0.15) : Qt.rgba(Root.Theme.primary.r, Root.Theme.primary.g, Root.Theme.primary.b, 0.2))
                                    : (connected ? Qt.rgba(1, 0.42, 0.42, 0.08) : Qt.rgba(Root.Theme.primary.r, Root.Theme.primary.g, Root.Theme.primary.b, 0.1))
                                border.width: 1
                                border.color: connected
                                    ? Qt.rgba(1, 0.42, 0.42, 0.3)
                                    : Qt.rgba(Root.Theme.primary.r, Root.Theme.primary.g, Root.Theme.primary.b, 0.3)

                                Behavior on color { ColorAnimation { duration: 120 } }

                                Text {
                                    id: actionLbl
                                    anchors.centerIn: parent
                                    text: connected ? "Disconnect" : "Connect"
                                    font.family: Root.Theme.fontFamily
                                    font.pixelSize: Root.Theme.fontSizeXS
                                    font.weight: Font.Medium
                                    color: connected ? Root.Theme.error : Root.Theme.primary
                                }

                                MouseArea {
                                    id: actionMA
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (connected) {
                                            disconnProc.command = ["bluetoothctl", "disconnect", mac];
                                            disconnProc.running = true;
                                        } else {
                                            connProc.command = ["bluetoothctl", "connect", mac];
                                            connProc.running = true;
                                        }
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: dma
                            anchors.fill: parent
                            hoverEnabled: true
                            propagateComposedEvents: true
                        }
                    }
                }

                // ── Pair Status ────────────────────────────────────────────
                Rectangle {
                    visible: bt.pairStatus !== ""
                    Layout.fillWidth: true
                    Layout.leftMargin: Root.Theme.paddingNormal
                    Layout.rightMargin: Root.Theme.paddingNormal
                    Layout.topMargin: 8
                    implicitHeight: pairStatusText.implicitHeight + 14
                    radius: Root.Theme.radiusSmall
                    color: bt.pairStatus.includes("failed") ? Qt.rgba(1, 0.42, 0.42, 0.1)
                         : bt.pairStatus.includes("successfully") ? Qt.rgba(Root.Theme.primary.r, Root.Theme.primary.g, Root.Theme.primary.b, 0.1)
                         : Qt.rgba(Root.Theme.textSecondary.r, Root.Theme.textSecondary.g, Root.Theme.textSecondary.b, 0.08)
                    border.width: 1
                    border.color: bt.pairStatus.includes("failed") ? Qt.rgba(1, 0.42, 0.42, 0.25)
                               : bt.pairStatus.includes("successfully") ? Qt.rgba(Root.Theme.primary.r, Root.Theme.primary.g, Root.Theme.primary.b, 0.25)
                               : Qt.rgba(Root.Theme.textSecondary.r, Root.Theme.textSecondary.g, Root.Theme.textSecondary.b, 0.15)

                    Text {
                        id: pairStatusText
                        anchors.centerIn: parent
                        text: bt.pairStatus
                        font.family: Root.Theme.fontFamily
                        font.pixelSize: Root.Theme.fontSizeSmall
                        color: bt.pairStatus.includes("failed") ? Root.Theme.error
                             : bt.pairStatus.includes("successfully") ? Root.Theme.primary
                             : Root.Theme.textSecondary
                        width: parent.width - 16
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                    }
                }

                // ── Scanning status ────────────────────────────────────────
                Text {
                    visible: bt.discoveryScanning
                    text: "Scanning for nearby devices\u2026"
                    font.family: Root.Theme.fontFamily
                    font.pixelSize: Root.Theme.fontSizeSmall
                    font.italic: true
                    color: Root.Theme.textSecondary
                    opacity: 0.7
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    Layout.topMargin: Root.Theme.paddingNormal
                }

                // ── Nearby Devices section ───────────────────────────
                Item {
                    visible: unpairedModel.count > 0
                    Layout.fillWidth: true
                    Layout.topMargin: 16
                    Layout.preferredHeight: 1

                    // Separator
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: Root.Theme.paddingNormal
                        anchors.rightMargin: Root.Theme.paddingNormal
                        height: 1
                        color: Root.Theme.surfaceContainerHigh
                    }
                }

                Text {
                    visible: unpairedModel.count > 0
                    text: "NEARBY DEVICES"
                    font.family: Root.Theme.fontFamily
                    font.pixelSize: Root.Theme.fontSizeXS
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1
                    color: Qt.rgba(Root.Theme.textSecondary.r, Root.Theme.textSecondary.g, Root.Theme.textSecondary.b, 0.6)
                    Layout.fillWidth: true
                    Layout.leftMargin: Root.Theme.paddingNormal + 4
                    Layout.rightMargin: Root.Theme.paddingNormal
                    Layout.topMargin: 12
                    Layout.bottomMargin: 2
                }

                Repeater {
                    model: unpairedModel

                    delegate: Rectangle {
                        required property int index
                        required property string mac
                        required property string name

                        Layout.fillWidth: true
                        Layout.leftMargin: Root.Theme.paddingNormal
                        Layout.rightMargin: Root.Theme.paddingNormal
                        implicitHeight: 56
                        radius: Root.Theme.radiusSmall
                        color: uma.containsMouse ? Root.Theme.surfaceContainerHigh : Root.Theme.surfaceContainer
                        border.width: 1
                        border.color: Qt.rgba(Root.Theme.surfaceContainerHigh.r, Root.Theme.surfaceContainerHigh.g, Root.Theme.surfaceContainerHigh.b, 0.5)

                        Behavior on color { ColorAnimation { duration: 120 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 10

                            // Icon circle
                            Rectangle {
                                Layout.preferredWidth: 34
                                Layout.preferredHeight: 34
                                radius: 17
                                color: Qt.rgba(Root.Theme.textSecondary.r, Root.Theme.textSecondary.g, Root.Theme.textSecondary.b, 0.10)

                                Text {
                                    anchors.centerIn: parent
                                    text: "\u{f00b1}"
                                    font.family: Root.Theme.fontFamily
                                    font.pixelSize: 15
                                    color: Root.Theme.textSecondary
                                    opacity: 0.7
                                }
                            }

                            // Name + MAC
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                Text {
                                    text: name
                                    font.family: Root.Theme.fontFamily
                                    font.pixelSize: Root.Theme.fontSizeNormal
                                    color: Root.Theme.textSecondary
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: mac
                                    font.family: Root.Theme.fontFamily
                                    font.pixelSize: Root.Theme.fontSizeXS
                                    color: Qt.rgba(Root.Theme.textSecondary.r, Root.Theme.textSecondary.g, Root.Theme.textSecondary.b, 0.4)
                                    Layout.fillWidth: true
                                }
                            }

                            // Pair button
                            Rectangle {
                                implicitWidth: pairLbl.implicitWidth + 18
                                implicitHeight: 28
                                radius: 14
                                color: bt.pairingMAC === mac ? Root.Theme.primary
                                    : pairMA.containsMouse
                                        ? Qt.rgba(Root.Theme.primary.r, Root.Theme.primary.g, Root.Theme.primary.b, 0.2)
                                        : Qt.rgba(Root.Theme.primary.r, Root.Theme.primary.g, Root.Theme.primary.b, 0.1)
                                border.width: 1
                                border.color: bt.pairingMAC === mac
                                    ? Root.Theme.primary
                                    : Qt.rgba(Root.Theme.primary.r, Root.Theme.primary.g, Root.Theme.primary.b, 0.3)

                                Behavior on color { ColorAnimation { duration: 120 } }

                                Text {
                                    id: pairLbl
                                    anchors.centerIn: parent
                                    text: bt.pairingMAC === mac ? "Pairing\u2026" : "Pair"
                                    font.family: Root.Theme.fontFamily
                                    font.pixelSize: Root.Theme.fontSizeXS
                                    font.weight: Font.Medium
                                    color: bt.pairingMAC === mac ? Root.Theme.textPrimary : Root.Theme.primary
                                }

                                MouseArea {
                                    id: pairMA
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { if (bt.pairingMAC === "") bt.pairDevice(mac); }
                                }
                            }
                        }

                        MouseArea {
                            id: uma
                            anchors.fill: parent
                            hoverEnabled: true
                            propagateComposedEvents: true
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
