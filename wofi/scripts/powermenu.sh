WOFI_CONFIG_PATH=$HOME/.config/wofi

menu="img:$WOFI_CONFIG_PATH/icons/power.svg:text:Power Off\nimg:$WOFI_CONFIG_PATH/icons/reboot.svg:text:Reboot\nimg:$WOFI_CONFIG_PATH/icons/lock.svg:text:Lock Screen\nimg:$WOFI_CONFIG_PATH/icons/suspend.svg:text:Suspend"

get_menu() {
	echo -e "$menu"
}

exec_commmand() {
	cmd_str=$(echo "$1" | awk -F'text:' '{print $2}')

	if [[ "$cmd_str" == "Power Off" ]]; then
		systemctl poweroff
	elif [[ "$cmd_str" == "Reboot" ]]; then
		systemctl reboot
	elif [[ "$cmd_str" == "Suspend" ]]; then
		systemctl suspend
	elif [[ "$cmd_str" == "Lock Screen" ]]; then
		hyprlock
	fi
}


# Show menu and execute command
menu_selected=""
if [[ "$1" == "--list" ]]; then
	menu_selected="$(get_menu | wofi -d)"
elif [[ "$1" == "--grid" ]]; then
	menu_selected="$(get_menu | wofi -d --columns=2)"
fi

if [[ "$menu_selected" != "" ]]; then
	exec_commmand "$menu_selected"
fi