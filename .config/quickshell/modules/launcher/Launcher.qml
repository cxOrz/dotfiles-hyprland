import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../.." as Root

Scope {
    id: launcher

    property bool panelVisible: false
    property bool _showing: false
    property bool _panelOpen: false
    property string searchText: ""

    // ── Keyboard navigation state ────────────────────────────────
    property int kbSection: 0   // 0 = recent row, 1 = app grid
    property int kbIndex: 0
    property int gridColumns: 5

    // ── Icon path cache (icon name -> file path) ─────────────────
    property var iconCache: ({})

    Process {
        id: iconResolveProc
        command: ["/bin/sh", "-c", "~/.config/quickshell/scripts/resolve-icons.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                var cache = {};
                var lines = text.trim().split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var parts = lines[i].split("\t");
                    if (parts.length === 2 && parts[1] !== "") {
                        cache[parts[0]] = parts[1];
                    }
                }
                launcher.iconCache = cache;
            }
        }
    }

    Component.onCompleted: {
        iconResolveProc.running = true;
        recentReadProc.running = true;
    }

    function resolveIcon(iconName) {
        if (!iconName || iconName === "") return "";
        if (iconName.startsWith("/")) return "file://" + iconName;
        var path = iconCache[iconName];
        if (path) return "file://" + path;
        return "";
    }

    // ── Recent apps ──────────────────────────────────────────────
    property var recentAppNames: []
    property int maxRecent: 5

    Process {
        id: recentReadProc
        command: ["/bin/sh", "-c", "mkdir -p ~/.cache/quickshell && cat ~/.cache/quickshell/recent-apps.txt 2>/dev/null || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                var names = [];
                if (text.trim() !== "") {
                    var lines = text.trim().split("\n");
                    for (var i = 0; i < lines.length && i < launcher.maxRecent; i++) {
                        var n = lines[i].trim();
                        if (n !== "") names.push(n);
                    }
                }
                launcher.recentAppNames = names;
            }
        }
    }

    function recordRecentApp(appName) {
        var names = recentAppNames.slice();
        // Remove duplicate
        var idx = names.indexOf(appName);
        if (idx >= 0) names.splice(idx, 1);
        // Prepend
        names.unshift(appName);
        // Trim
        if (names.length > maxRecent) names = names.slice(0, maxRecent);
        recentAppNames = names;
        // Write to file
        recentWriteProc.command = ["/bin/sh", "-c",
            "mkdir -p ~/.cache/quickshell && printf '%s\\n' " +
            names.map(function(n) { return "'" + n.replace(/'/g, "'\\''") + "'"; }).join(" ") +
            " > ~/.cache/quickshell/recent-apps.txt"];
        recentWriteProc.running = true;
    }

    Process { id: recentWriteProc }

    // Map recent names back to plain data objects {name, icon, entry}
    // (plain JS objects avoid QObject property access issues from inside Loader)
    property var recentApps: {
        var result = [];
        var names = recentAppNames;
        for (var i = 0; i < names.length; i++) {
            for (var j = 0; j < allApps.length; j++) {
                if (allApps[j].name === names[i]) {
                    var e = allApps[j];
                    result.push({ name: e.name, icon: e.icon, entry: e });
                    break;
                }
            }
        }
        return result;
    }

    // ── Filtered app list ────────────────────────────────────────
    property var allApps: {
        var apps = [];
        var entries = DesktopEntries.applications.values;
        for (var i = 0; i < entries.length; i++) {
            var entry = entries[i];
            if (entry && !entry.noDisplay && entry.name !== "") {
                apps.push(entry);
            }
        }
        apps.sort(function(a, b) {
            return a.name.localeCompare(b.name);
        });
        return apps;
    }

    property var filteredApps: {
        if (searchText === "") return allApps;
        var query = searchText.toLowerCase();
        return allApps.filter(function(entry) {
            if (entry.name.toLowerCase().indexOf(query) >= 0) return true;
            if (entry.genericName && entry.genericName.toLowerCase().indexOf(query) >= 0) return true;
            if (entry.comment && entry.comment.toLowerCase().indexOf(query) >= 0) return true;
            if (entry.keywords) {
                for (var k = 0; k < entry.keywords.length; k++) {
                    if (entry.keywords[k].toLowerCase().indexOf(query) >= 0) return true;
                }
            }
            return false;
        });
    }

    // Launch app and record it
    function launchApp(entry) {
        recordRecentApp(entry.name);
        entry.execute();
        panelVisible = false;
    }

    // ── Keyboard navigation ───────────────────────────────────────
    function handleNavKey(dir) {
        var recentVisible = recentApps.length > 0 && searchText === "";
        var recentCount = recentApps.length;
        var gridCount = filteredApps.length;
        var cols = gridColumns;

        if (recentVisible && kbSection === 0) {
            // Recent row (horizontal)
            if (dir === "left") {
                if (kbIndex > 0) kbIndex--;
            } else if (dir === "right") {
                if (kbIndex < recentCount - 1) kbIndex++;
            } else if (dir === "down") {
                if (gridCount > 0) { kbSection = 1; kbIndex = 0; }
            }
            // up in recent row: do nothing
        } else {
            // App grid (2D)
            if (dir === "left") {
                if (kbIndex > 0) kbIndex--;
            } else if (dir === "right") {
                if (kbIndex < gridCount - 1) kbIndex++;
            } else if (dir === "up") {
                var upIdx = kbIndex - cols;
                if (upIdx >= 0) {
                    kbIndex = upIdx;
                } else if (recentVisible) {
                    kbSection = 0; kbIndex = 0;
                }
            } else if (dir === "down") {
                var downIdx = kbIndex + cols;
                if (downIdx < gridCount) kbIndex = downIdx;
            }
        }
    }

    function getKeyboardSelectedApp() {
        if (kbSection === 0 && kbIndex >= 0 && kbIndex < recentApps.length)
            return recentApps[kbIndex].entry;
        if (kbSection === 1 && kbIndex >= 0 && kbIndex < filteredApps.length)
            return filteredApps[kbIndex];
        return null;
    }

    onPanelVisibleChanged: {
        if (panelVisible) {
            _showing = true;
            searchText = "";
            // Default selection: first recent app (or first grid app if no recent)
            kbSection = recentApps.length > 0 ? 0 : 1;
            kbIndex = 0;
        } else {
            _panelOpen = false;
        }
    }

    // ── IPC handlers ─────────────────────────────────────────────
    IpcHandler {
        target: "launcher"

        function toggle(): void { launcher.panelVisible = !launcher.panelVisible }
        function show(): void { launcher.panelVisible = true }
        function hide(): void { launcher.panelVisible = false }
    }

    // ── Overlay window ───────────────────────────────────────────
    Loader {
        active: launcher._showing

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

            WlrLayershell.namespace: "quickshell:launcher"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            Component.onCompleted: openDelayTimer.start()

            Timer {
                id: openDelayTimer
                interval: 16
                repeat: false
                onTriggered: if (launcher.panelVisible) launcher._panelOpen = true
            }

            Shortcut {
                sequence: "Escape"
                onActivated: launcher.panelVisible = false
            }

            // Click-outside to close
            MouseArea {
                anchors.fill: parent
                onClicked: launcher.panelVisible = false
            }

            // ── Clip region (above shelf/waybar) ─────────────────
            Item {
                id: panelClip
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Root.Theme.shelfHeight
                clip: true

                // ── Launcher panel — bottom-left, ChromeOS style ─
                Rectangle {
                    id: panel

                    property int columns: 5
                    property real cellW: 130
                    property real panelW: columns * cellW + 48
                    property real panelH: Math.min(panelClip.height * 0.78, 780)

                    width: panelW
                    height: panelH

                    // Bottom-left positioning
                    anchors.left: parent.left
                    anchors.leftMargin: 12

                    states: [
                        State {
                            name: "visible"
                            when: launcher._panelOpen
                            PropertyChanges {
                                target: panel
                                y: panelClip.height - panel.height - 8
                                opacity: 1
                            }
                        },
                        State {
                            name: "hidden"
                            when: !launcher._panelOpen
                            PropertyChanges {
                                target: panel
                                y: panelClip.height + 20
                                opacity: 0
                            }
                        }
                    ]

                    transitions: [
                        Transition {
                            from: "hidden"
                            to: "visible"
                            ParallelAnimation {
                                NumberAnimation {
                                    property: "y"
                                    duration: 200
                                    easing.type: Easing.OutCubic
                                }
                                NumberAnimation {
                                    property: "opacity"
                                    duration: 200
                                    easing.type: Easing.OutCubic
                                }
                            }
                        },
                        Transition {
                            from: "visible"
                            to: "hidden"
                            SequentialAnimation {
                                ParallelAnimation {
                                    NumberAnimation {
                                        property: "y"
                                        duration: 200
                                        easing.type: Easing.InCubic
                                    }
                                    NumberAnimation {
                                        property: "opacity"
                                        duration: 200
                                        easing.type: Easing.InCubic
                                    }
                                }
                                ScriptAction {
                                    script: launcher._showing = false
                                }
                            }
                        }
                    ]

                    radius: 28
                    color: Qt.rgba(Root.Theme.panelBg.r, Root.Theme.panelBg.g, Root.Theme.panelBg.b, 0.78)
                    border.width: 1
                    border.color: Qt.rgba(Root.Theme.panelBorder.r,
                                           Root.Theme.panelBorder.g,
                                           Root.Theme.panelBorder.b, 0.3)

                    // Block click-through
                    MouseArea {
                        anchors.fill: parent
                        onClicked: (mouse) => mouse.accepted = true
                    }

                    // ── Content layout ───────────────────────────
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.topMargin: 20
                        anchors.bottomMargin: 20
                        anchors.leftMargin: 24
                        anchors.rightMargin: 24
                        spacing: 16

                        // ── Search bar (ChromeOS pill) ───────────
                        Rectangle {
                            id: searchBar
                            Layout.fillWidth: true
                            Layout.preferredHeight: 48
                            radius: 24
                            color: Root.Theme.surfaceContainer

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16
                                spacing: 12

                                Text {
                                    text: "\uf002"
                                    font.pixelSize: 15
                                    font.family: Root.Theme.fontFamily
                                    color: Root.Theme.textSecondary
                                }

                                TextInput {
                                    id: searchInput
                                    Layout.fillWidth: true
                                    font.pixelSize: 13
                                    font.family: Root.Theme.fontFamily
                                    color: Root.Theme.textPrimary
                                    clip: true
                                    selectByMouse: true
                                    selectionColor: Root.Theme.primary

                                    onTextChanged: {
                                        launcher.searchText = text;
                                        // Reset kb selection on search change
                                        if (text !== "") {
                                            launcher.kbSection = 1;
                                            launcher.kbIndex = 0;
                                        } else {
                                            launcher.kbSection = launcher.recentApps.length > 0 ? 0 : 1;
                                            launcher.kbIndex = 0;
                                        }
                                    }

                                    // Auto-focus when component loads
                                    Component.onCompleted: focusTimer.start()

                                    Timer {
                                        id: focusTimer
                                        interval: 50
                                        repeat: false
                                        onTriggered: searchInput.forceActiveFocus()
                                    }

                                    Text {
                                        anchors.fill: parent
                                        text: "Search your apps..."
                                        font: searchInput.font
                                        color: Root.Theme.textSecondary
                                        visible: !searchInput.text
                                        verticalAlignment: Text.AlignVCenter
                                    }

                                    Keys.onReturnPressed: {
                                        var app = launcher.getKeyboardSelectedApp();
                                        if (app) {
                                            launcher.launchApp(app);
                                        } else if (launcher.filteredApps.length > 0) {
                                            launcher.launchApp(launcher.filteredApps[0]);
                                        }
                                    }

                                    Keys.onUpPressed: (event) => {
                                        launcher.handleNavKey("up");
                                        event.accepted = true;
                                    }
                                    Keys.onDownPressed: (event) => {
                                        launcher.handleNavKey("down");
                                        event.accepted = true;
                                    }
                                    Keys.onLeftPressed: (event) => {
                                        if (searchInput.text === "") {
                                            launcher.handleNavKey("left");
                                            event.accepted = true;
                                        }
                                    }
                                    Keys.onRightPressed: (event) => {
                                        if (searchInput.text === "") {
                                            launcher.handleNavKey("right");
                                            event.accepted = true;
                                        }
                                    }
                                }
                            }
                        }

                        // ── Scrollable content (recent apps + app grid) ─
                        Item {
                            id: scrollContainer
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            // Scroll to keep keyboard-selected item visible
                            function scrollToSelected() {
                                var recentH = recentSection.visible
                                    ? recentSection.height + scrollContent.spacing
                                    : 0;
                                var targetY, itemH;
                                if (launcher.kbSection === 0) {
                                    targetY = 0;
                                    itemH = 116;
                                } else {
                                    var row = Math.floor(launcher.kbIndex / panel.columns);
                                    targetY = recentH + row * 126;
                                    itemH = 126;
                                }
                                var viewH = appFlickable.height;
                                if (targetY < appFlickable.contentY)
                                    appFlickable.contentY = targetY;
                                else if (targetY + itemH > appFlickable.contentY + viewH)
                                    appFlickable.contentY = Math.max(0, targetY + itemH - viewH);
                            }

                            Connections {
                                target: launcher
                                function onKbIndexChanged() { scrollContainer.scrollToSelected() }
                                function onKbSectionChanged() { scrollContainer.scrollToSelected() }
                            }

                            Flickable {
                                id: appFlickable
                                anchors.fill: parent
                                contentWidth: width
                                contentHeight: scrollContent.height
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds
                                flickDeceleration: 3000

                                Column {
                                    id: scrollContent
                                    width: appFlickable.width
                                    spacing: 8

                                    // ── Recent apps section (only when not searching) ─
                                    Column {
                                        id: recentSection
                                        width: parent.width
                                        spacing: 8
                                        visible: launcher.recentApps.length > 0 && launcher.searchText === ""

                                        Text {
                                            text: "Recent"
                                            font.pixelSize: 12
                                            font.family: Root.Theme.fontFamily
                                            color: Root.Theme.textSecondary
                                        }

                                        Row {
                                            spacing: 4

                                             Repeater {
                                                model: launcher.recentApps

                                                AppIcon {
                                                    required property var modelData
                                                    required property int index
                                                    appName: modelData.name
                                                    iconSource: launcher.resolveIcon(modelData.icon)
                                                    isSelected: launcher.kbSection === 0 && launcher.kbIndex === index
                                                    onClicked: launcher.launchApp(modelData.entry)
                                                }
                                            }
                                        }

                                        // Separator
                                        Rectangle {
                                            width: parent.width
                                            height: 1
                                            color: Qt.rgba(Root.Theme.textSecondary.r, Root.Theme.textSecondary.g, Root.Theme.textSecondary.b, 0.3)
                                        }
                                    }

                                    // ── App grid ─────────────────────────
                                    Flow {
                                        id: appGrid
                                        width: parent.width

                                        property real cellWidth: width / panel.columns

                                        Repeater {
                                            model: launcher.filteredApps

                                            Item {
                                                required property var modelData
                                                required property int index
                                                width: appGrid.cellWidth
                                                height: 126

                                                AppIcon {
                                                    anchors.centerIn: parent
                                                    appName: modelData.name
                                                    iconSource: launcher.resolveIcon(modelData.icon)
                                                    isSelected: launcher.kbSection === 1 && launcher.kbIndex === index
                                                    onClicked: launcher.launchApp(modelData)
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "No apps found"
                                font.pixelSize: Root.Theme.fontSizeNormal
                                font.family: Root.Theme.fontFamily
                                color: Root.Theme.textSecondary
                                visible: launcher.filteredApps.length === 0
                            }
                        }
                    }
                }
            }
        }
    }
}
