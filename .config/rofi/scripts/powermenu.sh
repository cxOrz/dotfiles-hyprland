#!/usr/bin/env bash

ICON_PATH="$HOME/.config/rofi/assets" 

shutdown="Shutdown\0icon\x1f${ICON_PATH}/power.png"
reboot="Reboot\0icon\x1f${ICON_PATH}/reboot.png"
lock="Lock Screen\0icon\x1f${ICON_PATH}/lock.png"
suspend="Suspend\0icon\x1f${ICON_PATH}/suspend.png"

selected_option=$(echo -en "$shutdown\n$reboot\n$lock\n$suspend" | rofi -dmenu -markup-rows)

echo $selected_option

if [[ -n "$selected_option" ]]; then
    case "$selected_option" in
        "Shutdown") systemctl poweroff ;;
        "Reboot") systemctl reboot ;;
        "Lock Screen") hyprlock & ;;
        "Suspend") systemctl suspend ;;
    esac
fi

exit 0