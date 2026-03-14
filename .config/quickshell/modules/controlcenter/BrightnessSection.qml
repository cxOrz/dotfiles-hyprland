import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../.." as Root

Item {
    id: root

    implicitHeight: contentColumn.implicitHeight
    implicitWidth: parent ? parent.width : 300

    property real brightness: 0.5
    property bool brightnessAvailable: true

    // ── Read brightness via brightnessctl -m ──
    Process {
        id: readProc
        command: ["brightnessctl", "--class=backlight", "-m"]
        stdout: StdioCollector {
            onStreamFinished: {
                // format: device,class,current,percentage%,max
                var parts = text.trim().split(",");
                if (parts.length >= 5) {
                    var current = parseFloat(parts[2]);
                    var max = parseFloat(parts[4]);
                    if (!isNaN(current) && !isNaN(max) && max > 0)
                        root.brightness = current / max;
                }
            }
        }
        onExited: (code, status) => {
            if (code !== 0)
                root.brightnessAvailable = false;
        }
    }

    // ── Set brightness process ──
    Process {
        id: setProc
    }

    Component.onCompleted: readProc.running = true

    function setBrightness(value) {
        var clamped = Math.min(Math.max(value, 0.0), 1.0);
        root.brightness = clamped;
        setProc.command = ["brightnessctl", "set", Math.round(clamped * 100) + "%"];
        setProc.running = true;
    }

    function brightnessIcon(level) {
        if (level < 0.33) return "\u{F03DE}";  // 󰃞 dim
        if (level < 0.66) return "\u{F03DF}";  // 󰃟 mid
        return "\u{F03E0}";                     // 󰃠 bright
    }

    // ── UI Layout ──
    ColumnLayout {
        id: contentColumn
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        // ── Pill-shaped brightness slider ──
        Rectangle {
            Layout.fillWidth: true
            height: Root.Theme.sliderHeight
            radius: Root.Theme.sliderHeight / 2
            color: Root.Theme.sliderTrack
            clip: true
            visible: root.brightnessAvailable

            // Active fill
            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: Math.max(parent.height, parent.width * root.brightness)
                radius: parent.radius
                color: Root.Theme.sliderActiveTrack
            }

            // Brightness icon (left)
            Text {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                z: 1
                text: root.brightnessIcon(root.brightness)
                font.family: Root.Theme.fontFamily
                font.pixelSize: Root.Theme.fontSizeLarge
                color: Root.Theme.bg
            }

            // Percentage text (right)
            Text {
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                z: 1
                text: Math.round(root.brightness * 100) + "%"
                font.family: Root.Theme.fontFamily
                font.pixelSize: Root.Theme.fontSizeNormal
                color: root.brightness > 0.85 ? Root.Theme.bg : Root.Theme.textSecondary
            }

            // Interactive drag/click area
            MouseArea {
                anchors.fill: parent
                preventStealing: true

                onPressed: (mouse) => {
                    var ratio = mouse.x / width;
                    root.setBrightness(ratio);
                }

                onPositionChanged: (mouse) => {
                    if (pressed) {
                        var ratio = mouse.x / width;
                        root.setBrightness(ratio);
                    }
                }
            }
        }
    }
}
