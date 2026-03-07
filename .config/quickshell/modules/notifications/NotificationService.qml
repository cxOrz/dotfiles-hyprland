pragma Singleton
import QtQuick
import Quickshell.Io

QtObject {
    id: root

    // Exposed notification list (JS array of parsed notification objects)
    property var notifications: []
    property int count: notifications.length

    // Notifications list change is auto-signaled via property assignment

    // Process to fetch dunst notification history
    property var historyProcess: Process {
        command: ["dunstctl", "history"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.parseHistory(this.text);
            }
        }
    }

    // Process for clearing all notifications
    property var clearProcess: Process {
        command: ["dunstctl", "history-clear"]
        onExited: function(exitCode, exitStatus) {
            if (exitCode === 0) {
                root.notifications = [];
            }
        }
    }

    // Process for removing a single notification
    property var removeProcess: Process {
        id: removeProc
        command: ["dunstctl", "history-rm", "0"]
        onExited: function(exitCode, exitStatus) {
            if (exitCode === 0) {
                root.refresh();
            }
        }
    }

    // SocketServer for live updates from dunst hook — disabled in v0.2.1 (no onMessage API)
    // Live updates use manual refresh on panel open instead
    // Parse the dunstctl history JSON output
    // Structure: { "type": "aa{sv}", "data": [[{...}, {...}]] }
    // Each notification field: { "type": "s"|"i"|"x", "data": <value> }
    function parseHistory(jsonText) {
        try {
            var parsed = JSON.parse(jsonText);
            var rawList = parsed.data && parsed.data[0] ? parsed.data[0] : [];
            var result = [];

            for (var i = 0; i < rawList.length; i++) {
                var raw = rawList[i];
                var notification = {
                    id: extractField(raw, "id", 0),
                    appName: extractField(raw, "appname", "Unknown"),
                    summary: extractField(raw, "summary", ""),
                    body: extractField(raw, "body", ""),
                    urgency: extractField(raw, "urgency", "NORMAL"),
                    timestamp: extractField(raw, "timestamp", 0),
                    iconPath: extractField(raw, "icon_path", ""),
                    category: extractField(raw, "category", "")
                };
                result.push(notification);
            }

            root.notifications = result;
        } catch (e) {
            console.warn("NotificationService: Failed to parse dunstctl history:", e);
            root.notifications = [];
        }
    }

    // Parse incoming JSON from dunst hook script — kept for future use
    // (SocketServer not available in v0.2.1; panel refreshes via dunstctl on open)

    // Extract a field from dunstctl's nested {type, data} structure
    function extractField(obj, fieldName, fallback) {
        if (obj && obj[fieldName] && obj[fieldName].data !== undefined) {
            return obj[fieldName].data;
        }
        return fallback;
    }

    // Compute relative timestamp string
    // dunstctl returns monotonic clock microseconds (from boot), not Unix epoch.
    // We detect this by checking if the value is unreasonably old (> 7 days from "now").
    // In that case, we display duration from zero reference as a best-effort fallback.
    function relativeTime(unixTimestamp) {
        if (unixTimestamp <= 0) return "";

        // dunstctl timestamps are monotonic microseconds since boot
        var timestampMs = unixTimestamp / 1000;
        var now = Date.now();
        var diffSec = Math.floor((now - timestampMs) / 1000);

        // If result is nonsensical (e.g. "20000 days ago"), fall back to monotonic offset
        if (diffSec < 0 || diffSec > 7 * 86400) {
            // Treat timestamp as microseconds since boot; show duration from boot
            var bootSec = Math.floor(timestampMs / 1000);
            if (bootSec < 60) return "just now";
            if (bootSec < 3600) {
                var bmins = Math.floor(bootSec / 60);
                return bmins + (bmins === 1 ? " min" : " mins") + " after boot";
            }
            var bhours = Math.floor(bootSec / 3600);
            return bhours + (bhours === 1 ? " hr" : " hrs") + " after boot";
        }

        if (diffSec < 60) return "just now";
        if (diffSec < 3600) {
            var mins = Math.floor(diffSec / 60);
            return mins + (mins === 1 ? " min ago" : " mins ago");
        }
        if (diffSec < 86400) {
            var hours = Math.floor(diffSec / 3600);
            return hours + (hours === 1 ? " hour ago" : " hours ago");
        }
        var days = Math.floor(diffSec / 86400);
        return days + (days === 1 ? " day ago" : " days ago");
    }

    // Public methods
    function refresh() {
        historyProcess.running = true;
    }

    function clearAll() {
        clearProcess.running = true;
    }

    function removeNotification(notifId) {
        removeProcess.command = ["dunstctl", "history-rm", String(notifId)];
        removeProcess.running = true;
    }
}
