import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import "../.." as Root

// VolumeOsd — bottom-center floating card, appears on any volume/mute change
// Auto-dismisses after 2 s of inactivity
Scope {
    id: volumeOsd

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    property var  audio:         Pipewire.defaultAudioSink
    readonly property real  currentVolume:  audio && audio.audio ? audio.audio.volume : 0
    readonly property bool  currentMuted:   audio && audio.audio ? audio.audio.muted  : false
    readonly property int   volumePercent:  Math.round(currentVolume * 100)

    // Ignore initial Pipewire property population on startup
    property bool _ready: false
    Component.onCompleted: readyTimer.start()
    Timer { id: readyTimer; interval: 600; repeat: false; onTriggered: volumeOsd._ready = true }

    onCurrentVolumeChanged: if (_ready) osdWin.showOsd()
    onCurrentMutedChanged:  if (_ready) osdWin.showOsd()

    function volumeIcon(vol, muted) {
        if (muted || vol === 0) return "󰖁"
        if (vol < 0.34)         return "󰕿"
        if (vol < 0.67)         return "󰖀"
        return "󰕾"
    }

    // ── Overlay window ──────────────────────────────────────────────
    PanelWindow {
        id: osdWin
        visible: false
        color:   "transparent"
        exclusionMode:               ExclusionMode.Ignore
        WlrLayershell.layer:         WlrLayer.Overlay
        WlrLayershell.namespace:     "quickshell:volume-osd"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        // Full-width bottom strip — just tall enough to hold the card
        anchors.bottom: true
        anchors.left:   true
        anchors.right:  true
        height: Root.Theme.shelfHeight + 16 + 52 + 20   // bottomMargin + cardH + topSlack

        function showOsd() {
            dismissAnim.stop()
            if (!visible) {
                osdCard._opacity = 0
                osdCard._slideY  = 14
                visible = true
                appearAnim.start()
            }
            dismissTimer.restart()
        }

        // Auto-dismiss
        Timer {
            id: dismissTimer
            interval: 2000
            repeat:   false
            onTriggered: dismissAnim.start()
        }

        // Appear: slide up + fade in
        ParallelAnimation {
            id: appearAnim
            NumberAnimation {
                target: osdCard; property: "_opacity"
                to: 1; duration: 180; easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: osdCard; property: "_slideY"
                to: 0; duration: 220; easing.type: Easing.OutCubic
            }
        }

        // Dismiss: fade out, then hide window
        SequentialAnimation {
            id: dismissAnim
            NumberAnimation {
                target: osdCard; property: "_opacity"
                to: 0; duration: 200; easing.type: Easing.InQuad
            }
            ScriptAction { script: osdWin.visible = false }
        }

        // ── Card container — fixed position just above the shelf ────
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom:           parent.bottom
            anchors.bottomMargin:     Root.Theme.shelfHeight + 16
            width:  300
            height: 52

            // The animating card rectangle
            Rectangle {
                id: osdCard
                property real _opacity: 0
                property real _slideY:  14

                width:   parent.width
                height:  parent.height
                y:       _slideY
                opacity: _opacity

                radius: 26
                color:  Qt.rgba(Root.Theme.panelBg.r,
                                Root.Theme.panelBg.g,
                                Root.Theme.panelBg.b, 0.92)
                border.width: 1
                border.color: Qt.rgba(Root.Theme.panelBorder.r,
                                      Root.Theme.panelBorder.g,
                                      Root.Theme.panelBorder.b, 0.45)

                RowLayout {
                    anchors.fill:        parent
                    anchors.leftMargin:  18
                    anchors.rightMargin: 18
                    spacing: 12

                    // ── Volume icon ────────────────────────────────
                    Text {
                        text:             volumeOsd.volumeIcon(volumeOsd.currentVolume,
                                                               volumeOsd.currentMuted)
                        font.family:      Root.Theme.fontFamily
                        font.pixelSize:   18
                        color:            volumeOsd.currentMuted
                                              ? Root.Theme.textSecondary
                                              : Root.Theme.primary
                        Layout.alignment: Qt.AlignVCenter

                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    // ── Progress bar ───────────────────────────────
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        height: 6
                        radius: 3
                        color:  Root.Theme.sliderTrack

                        // Active fill
                        Rectangle {
                            anchors.top:    parent.top
                            anchors.bottom: parent.bottom
                            anchors.left:   parent.left
                            width:  Math.max(parent.height,
                                            parent.width * (volumeOsd.currentMuted
                                                            ? 0
                                                            : volumeOsd.currentVolume))
                            radius: parent.radius
                            color:  volumeOsd.currentMuted
                                        ? Qt.rgba(Root.Theme.sliderActiveTrack.r,
                                                  Root.Theme.sliderActiveTrack.g,
                                                  Root.Theme.sliderActiveTrack.b, 0.35)
                                        : Root.Theme.sliderActiveTrack

                            Behavior on width { NumberAnimation { duration: 80 } }
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                    }

                    // ── Percentage / Muted label ───────────────────
                    Text {
                        text:             volumeOsd.currentMuted
                                              ? "Muted"
                                              : (volumeOsd.volumePercent + "%")
                        font.family:      Root.Theme.fontFamily
                        font.pixelSize:   Root.Theme.fontSizeNormal
                        color:            Root.Theme.textPrimary
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: 42
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }
        }
    }
}
