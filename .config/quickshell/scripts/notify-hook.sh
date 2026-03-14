#!/bin/bash
# Dunst notification hook for QuickShell
# Receives dunst environment variables and sends JSON to QuickShell SocketServer
# Called by dunst for every new notification

# Extract and escape special characters in JSON strings
APP=$(printf '%s' "$DUNST_APP_NAME" | sed 's/"/\\"/g')
SUM=$(printf '%s' "$DUNST_SUMMARY" | sed 's/"/\\"/g')
BOD=$(printf '%s' "$DUNST_BODY" | sed 's/"/\\"/g')
URG="${DUNST_URGENCY:-NORMAL}"
ID="${DUNST_ID:-0}"

# Format JSON payload
JSON=$(printf '{"appname":"%s","summary":"%s","body":"%s","urgency":"%s","id":%s}\n' \
    "$APP" "$SUM" "$BOD" "$URG" "$ID")

# Send JSON to QuickShell SocketServer via Unix socket
# Using bash's exec with /dev/null fallback if socket unavailable
{
    exec 3<>/tmp/quickshell-notifications.sock 2>/dev/null
    if [ $? -eq 0 ]; then
        printf '%s' "$JSON" >&3
        exec 3>&-
    fi
} 2>/dev/null || true

# Signal waybar to refresh notification count immediately
pkill -RTMIN+1 waybar 2>/dev/null || true
