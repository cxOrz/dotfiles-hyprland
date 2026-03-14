import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../.." as Root

// StatusArea — Shelf status icon cluster (WiFi/Bluetooth/Battery/Volume/Clock)
// WiFi: nmcli CLI polling
// Bluetooth: bluetoothctl CLI polling
// Battery: Conditional via /sys/class/power_supply/BAT0
// Volume: Native Pipewire
// Clock: Timer-driven HH:mm
Item {
    id: root

    implicitWidth: statusRow.implicitWidth
    implicitHeight: statusRow.implicitHeight

    // ── WiFi state ──
    property int wifiSignal: -1  // -1 = disconnected, 0-100 = signal strength

    // ── Bluetooth state ──
    property bool btPowered: false

    // ── Battery state ──
    property bool hasBattery: false
    property int batteryLevel: 0
    property bool batteryCharging: false

    // ── Volume state (native Pipewire) ──
    property var nativeAudio: Pipewire.defaultAudioSink
    readonly property real currentVolume: nativeAudio && nativeAudio.audio ? nativeAudio.audio.volume : 0
    readonly property bool currentMuted: nativeAudio && nativeAudio.audio ? nativeAudio.audio.muted : false

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    // ── Clock ──
    property string timeText: Qt.formatDateTime(new Date(), "HH:mm")

    // ── Icon helpers ──
    function wifiIcon(signal) {
        if (signal < 0)   return "󰤭"  // disconnected
        if (signal <= 25) return "󰤯"  // weak
        if (signal <= 50) return "󰤟"  // fair
        if (signal <= 75) return "󰤢"  // good
        return "󰤨"                    // excellent
    }

    function volumeIcon(level, muted) {
        if (muted || level === 0) return "󰝟"
        if (level < 0.34) return "󰕿"
        if (level < 0.67) return "󰖀"
        return "󰕾"
    }

    function batteryIcon(level, charging) {
        if (charging) return "󰂄"
        if (level <= 10) return "󰁺"
        if (level <= 20) return "󰁻"
        if (level <= 30) return "󰁼"
        if (level <= 40) return "󰁽"
        if (level <= 50) return "󰁾"
        if (level <= 60) return "󰁿"
        if (level <= 70) return "󰂀"
        if (level <= 80) return "󰂁"
        if (level <= 90) return "󰂂"
        return "󰁹"
    }

    // WiFi: nmcli CLI
    Process {
        id: wifiProc
        command: ["nmcli", "-t", "-f", "ACTIVE,SIGNAL", "dev", "wifi"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim().split("\n")
                var signal = -1
                for (var i = 0; i < lines.length; i++) {
                    if (lines[i].startsWith("yes:")) {
                        signal = parseInt(lines[i].split(":")[1])
                        break
                    }
                }
                root.wifiSignal = signal
            }
        }
    }

    // Bluetooth: bluetoothctl CLI
    Process {
        id: btProc
        command: ["bluetoothctl", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.btPowered = text.includes("Powered: yes")
            }
        }
    }

    // Battery: check sysfs existence
    Process {
        id: batteryCheckProc
        command: ["sh", "-c", "test -e /sys/class/power_supply/BAT0/capacity && echo yes || echo no"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.hasBattery = text.trim() === "yes"
                if (root.hasBattery) batteryReadProc.running = true
            }
        }
    }

    // Battery: read capacity from sysfs
    Process {
        id: batteryReadProc
        command: ["cat", "/sys/class/power_supply/BAT0/capacity"]
        stdout: StdioCollector {
            onStreamFinished: {
                var val = parseInt(text.trim())
                if (!isNaN(val)) root.batteryLevel = val
            }
        }
    }

    // Battery: charging status check
    Process {
        id: batteryStatusProc
        command: ["cat", "/sys/class/power_supply/BAT0/status"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.batteryCharging = text.trim() === "Charging" || text.trim() === "Full"
            }
        }
    }

    // Control center toggle (click handler)
    Process {
        id: ccToggleProc
        command: ["qs", "ipc", "call", "controlcenter", "toggle"]
        stdout: StdioCollector { }
    }

    // ── Polling timer for CLI status updates (every 5 seconds) ──
    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            wifiProc.running = true
            btProc.running = true
            if (root.hasBattery) {
                batteryReadProc.running = true
                batteryStatusProc.running = true
            }
        }
    }

    // ── Clock timer (every 30 seconds — close enough for HH:mm accuracy) ──
    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.timeText = Qt.formatDateTime(new Date(), "HH:mm")
    }

    // ── Init: check battery existence ──
    Component.onCompleted: batteryCheckProc.running = true

    // ── UI: clickable status row ──
    MouseArea {
        id: clickArea
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: ccToggleProc.startDetached()

        Row {
            id: statusRow
            spacing: 12
            anchors.centerIn: parent

            // WiFi icon
            Text {
                text: root.wifiIcon(root.wifiSignal)
                font.family: Root.Theme.fontFamily
                font.pixelSize: 18
                color: Root.Theme.textPrimary
                verticalAlignment: Text.AlignVCenter
            }

            // Bluetooth icon
            Text {
                text: root.btPowered ? "󰂯" : "󰂲"
                font.family: Root.Theme.fontFamily
                font.pixelSize: 18
                color: Root.Theme.textPrimary
                verticalAlignment: Text.AlignVCenter
            }

            // Battery (hidden if no battery hardware)
            Text {
                visible: root.hasBattery
                text: root.batteryIcon(root.batteryLevel, root.batteryCharging)
                font.family: Root.Theme.fontFamily
                font.pixelSize: 18
                color: root.batteryLevel <= 10 && !root.batteryCharging ? Root.Theme.error : Root.Theme.textPrimary
                verticalAlignment: Text.AlignVCenter
            }

            // Volume icon
            Text {
                text: root.volumeIcon(root.currentVolume, root.currentMuted)
                font.family: Root.Theme.fontFamily
                font.pixelSize: 18
                color: Root.Theme.textPrimary
                verticalAlignment: Text.AlignVCenter
            }

            // Clock (HH:mm)
            Text {
                text: root.timeText
                font.family: Root.Theme.fontFamily
                font.pixelSize: Root.Theme.fontSizeNormal
                color: Root.Theme.textSecondary
                verticalAlignment: Text.AlignVCenter
            }
        }
    }
}
