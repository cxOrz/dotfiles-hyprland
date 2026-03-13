#!/bin/bash
export WAYLAND_DISPLAY=wayland-1
export XDG_RUNTIME_DIR=/run/user/1000
export HYPRLAND_INSTANCE_SIGNATURE=$(ls /run/user/1000/hypr/ | head -1)
export YDOTOOL_SOCKET=/run/user/1000/.ydotool_socket

if [ ! -S "$YDOTOOL_SOCKET" ]; then
    systemctl --user start ydotool
    sleep 0.3
fi

hyprctl dispatch focuswindow "class:hyprland-share-picker"
sleep 0.2
ydotool key 15:1 15:0
sleep 0.3
ydotool key 57:1 57:0
