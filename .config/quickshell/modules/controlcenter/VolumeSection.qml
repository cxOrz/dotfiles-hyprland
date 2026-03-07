import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../.." as Root

// Volume Section — Pipewire audio control with wpctl fallback
// Native Quickshell.Services.Pipewire is primary; wpctl via Process is fallback
Item {
    id: root

    implicitHeight: contentColumn.implicitHeight
    implicitWidth: parent ? parent.width : 300

    // ── Pipewire native bindings ──
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var audio: sink ? sink.audio : null
    readonly property bool nativeAvailable: audio !== null

    // ── Unified state (native or fallback) ──
    readonly property real currentVolume: nativeAvailable ? audio.volume : fallbackVolume
    readonly property bool currentMuted: nativeAvailable ? audio.muted : fallbackMuted
    readonly property string sinkName: {
        if (nativeAvailable && sink) {
            return sink.nickname || sink.description || sink.name || "Unknown Device"
        }
        return fallbackSinkName
    }
    readonly property int volumePercent: Math.round(currentVolume * 100)

    // ── Fallback state (wpctl) ──
    property real fallbackVolume: 0.0
    property bool fallbackMuted: false
    property string fallbackSinkName: "Audio Output"

    // ── Bind the default sink via PwObjectTracker (REQUIRED for volume/muted) ──
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    // ── wpctl fallback: polling timer ──
    Timer {
        running: !root.nativeAvailable
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: wpctlGetVolume.running = true
    }

    // ── wpctl fallback: get volume process ──
    Process {
        id: wpctlGetVolume
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: StdioCollector {
            onStreamFinished: {
                var output = this.text.trim();
                // Parse "Volume: 0.50" or "Volume: 0.50 [MUTED]"
                var match = output.match(/Volume:\s*([\d.]+)(\s*\[MUTED\])?/);
                if (match) {
                    root.fallbackVolume = Math.min(parseFloat(match[1]), 1.0);
                    root.fallbackMuted = match[2] !== undefined;
                }
            }
        }
    }

    // ── wpctl fallback: set volume process ──
    Process {
        id: wpctlSetVolume
    }

    // ── wpctl fallback: toggle mute process ──
    Process {
        id: wpctlToggleMute
    }

    // ── Volume control functions ──
    function setVolume(value) {
        var clamped = Math.min(Math.max(value, 0.0), 1.0);
        if (nativeAvailable) {
            audio.volume = clamped;
        } else {
            wpctlSetVolume.exec(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", clamped.toFixed(2)]);
            fallbackVolume = clamped;
        }
    }

    function toggleMute() {
        if (nativeAvailable) {
            audio.muted = !audio.muted;
        } else {
            wpctlToggleMute.exec(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]);
            fallbackMuted = !fallbackMuted;
        }
    }

    function volumeIcon(level, muted) {
        if (muted || level === 0) return "󰕿";
        if (level < 0.34) return "󰕾";
        if (level < 0.67) return "󰖀";
        return "󰖁";
    }

    // ── UI Layout ──
    ColumnLayout {
        id: contentColumn
        anchors.fill: parent
        spacing: 8

        // ── Header row: icon + label + mute toggle ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // Dynamic volume icon
            Text {
                text: root.volumeIcon(root.currentVolume, root.currentMuted)
                font.family: Root.Theme.fontFamily
                font.pixelSize: Root.Theme.fontSizeLarge
                color: root.currentMuted ? Root.Theme.textSecondary : Root.Theme.accent
                Layout.alignment: Qt.AlignVCenter
            }

            // "Volume" label
            Text {
                text: "Volume"
                font.family: Root.Theme.fontFamily
                font.pixelSize: Root.Theme.fontSizeLarge
                font.bold: true
                color: Root.Theme.textPrimary
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
            }

            // Percentage display
            Text {
                text: root.volumePercent + "%"
                font.family: Root.Theme.fontFamily
                font.pixelSize: Root.Theme.fontSizeNormal
                color: root.currentMuted ? Root.Theme.textSecondary : Root.Theme.textPrimary
                Layout.alignment: Qt.AlignVCenter
            }

            // Mute toggle button
            Rectangle {
                width: 32
                height: 32
                radius: Root.Theme.radiusSmall
                color: muteArea.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                Layout.alignment: Qt.AlignVCenter

                Text {
                    anchors.centerIn: parent
                    text: root.currentMuted ? "󰕿" : "󰕾"
                    font.family: Root.Theme.fontFamily
                    font.pixelSize: Root.Theme.fontSizeLarge
                    color: root.currentMuted ? Root.Theme.textSecondary : Root.Theme.accent
                }

                MouseArea {
                    id: muteArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleMute()
                }
            }
        }

        // ── Volume slider ──
        Slider {
            id: volumeSlider
            Layout.fillWidth: true
            Layout.preferredHeight: 40

            from: 0.0
            to: 1.0
            value: root.currentVolume
            stepSize: 0.01
            opacity: root.currentMuted ? 0.5 : 1.0

            onMoved: root.setVolume(value)

            background: Rectangle {
                x: volumeSlider.leftPadding
                y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                width: volumeSlider.availableWidth
                height: 6
                radius: 3
                color: Root.Theme.bgTertiary

                // Filled portion
                Rectangle {
                    width: volumeSlider.visualPosition * parent.width
                    height: parent.height
                    radius: 3
                    color: root.currentMuted ? Root.Theme.textSecondary : Root.Theme.accent
                }
            }

            handle: Rectangle {
                x: volumeSlider.leftPadding + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
                y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                width: 16
                height: 16
                radius: 8
                color: root.currentMuted ? Root.Theme.textSecondary : Root.Theme.accent
                border.color: Root.Theme.bg
                border.width: 2

                // Subtle glow on hover/press
                scale: volumeSlider.pressed ? 1.15 : 1.0

                Behavior on scale {
                    NumberAnimation { duration: 100 }
                }
            }
        }

        // ── Sink name ──
        Text {
            text: root.sinkName
            font.family: Root.Theme.fontFamily
            font.pixelSize: Root.Theme.fontSizeNormal
            color: Root.Theme.textSecondary
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
    }
}
