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

    Component.onCompleted: iconResolveProc.running = true

    function resolveIcon(iconName) {
        if (!iconName || iconName === "") return "";
        if (iconName.startsWith("/")) return "file://" + iconName;
        var path = iconCache[iconName];
        if (path) return "file://" + path;
        return "";
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

    onPanelVisibleChanged: {
        if (panelVisible) {
            _showing = true;
            searchText = "";
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

                                    onTextChanged: launcher.searchText = text

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
                                        visible: !searchInput.text && !searchInput.activeFocus
                                        verticalAlignment: Text.AlignVCenter
                                    }

                                    Keys.onReturnPressed: {
                                        if (launcher.filteredApps.length > 0) {
                                            launcher.filteredApps[0].execute();
                                            launcher.panelVisible = false;
                                        }
                                    }
                                }
                            }
                        }

                        // ── App grid ─────────────────────────────
                        Item {
                            id: appGridContainer
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            Flickable {
                                id: appFlickable
                                anchors.fill: parent
                                contentWidth: width
                                contentHeight: appGrid.height
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds
                                flickDeceleration: 3000

                                Flow {
                                    id: appGrid
                                    width: appFlickable.width

                                    property int columns: panel.columns
                                    property real cellWidth: width / columns

                                    Repeater {
                                        model: launcher.filteredApps.length

                                        Item {
                                            width: appGrid.cellWidth
                                            height: 126

                                            AppIcon {
                                                anchors.centerIn: parent
                                                appName: launcher.filteredApps[index].name
                                                iconSource: launcher.resolveIcon(launcher.filteredApps[index].icon)
                                                onClicked: {
                                                    launcher.filteredApps[index].execute();
                                                    launcher.panelVisible = false;
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
