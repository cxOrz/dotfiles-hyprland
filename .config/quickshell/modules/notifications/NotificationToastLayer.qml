import QtQuick
import Quickshell
import Quickshell.Wayland
import "../.." as Root

// NotificationToastLayer — Wayland overlay that stacks toast popups top-right
// Listens to NotificationService.newNotification signal and auto-dismisses via timer
Scope {
    id: toastLayer

    // Internal model for active toasts
    ListModel { id: toastModel }

    // Listen for new notifications from NotificationService
    Connections {
        target: NotificationService

        function onNewNotification(notifId, appName, summary, body, urgency, timeout) {
            toastModel.append({
                notifId:  notifId,
                appName:  appName,
                summary:  summary,
                body:     body,
                urgency:  urgency,
                timeout:  timeout > 0 ? timeout : 5000
            })
        }
    }

    // ── Overlay window ────────────────────────────────────────────────────
    PanelWindow {
        id: toastWin
        visible:              toastModel.count > 0
        color:                "transparent"
        exclusionMode:        ExclusionMode.Ignore
        WlrLayershell.layer:          WlrLayer.Overlay
        WlrLayershell.namespace:      "quickshell:notifications-toast"
        WlrLayershell.keyboardFocus:  WlrKeyboardFocus.None

        // Anchor only top+right so the window doesn't cover the full screen
        anchors.top:   true
        anchors.right: true
        width:  400
        height: toastCol.implicitHeight + 40

        Column {
            id: toastCol
            anchors {
                top:         parent.top
                right:       parent.right
                topMargin:   Root.Theme.spacingLarge + 4
                rightMargin: Root.Theme.spacingLarge
            }
            spacing: Root.Theme.spacingSmall

            Repeater {
                model: toastModel

                delegate: Item {
                    id: delegateItem
                    width:  360
                    height: popup.height

                    NotificationPopup {
                        id:      popup
                        width:   parent.width
                        notifId: model.notifId
                        appName: model.appName
                        summary: model.summary
                        body:    model.body
                        urgency: model.urgency

                        onDismissed: function(id) {
                            NotificationService.removeNotification(id)
                            toastWin._removeById(id)
                        }
                    }

                    // Auto-dismiss timer
                    Timer {
                        property int _notifId: model.notifId
                        interval:  model.timeout
                        running:   true
                        repeat:    false
                        onTriggered: toastWin._removeById(_notifId)
                    }
                }
            }
        }

        // Helper: remove a toast from the model by notifId
        function _removeById(notifId) {
            for (var i = 0; i < toastModel.count; i++) {
                if (toastModel.get(i).notifId === notifId) {
                    toastModel.remove(i)
                    return
                }
            }
        }
    }
}
