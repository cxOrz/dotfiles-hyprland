#!/bin/bash
XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export WAYLAND_DISPLAY=wayland-1
export XDG_RUNTIME_DIR
export HYPRLAND_INSTANCE_SIGNATURE=$(ls "${XDG_RUNTIME_DIR}"/hypr/ | head -1)
export YDOTOOL_SOCKET="${XDG_RUNTIME_DIR}"/.ydotool_socket

if [ ! -S "$YDOTOOL_SOCKET" ]; then
    systemctl --user start ydotool
    sleep 0.3
fi

hyprctl dispatch focuswindow "class:hyprland-share-picker"
sleep 0.2
ydotool key 15:1 15:0
sleep 0.3
ydotool key 57:1 57:0
