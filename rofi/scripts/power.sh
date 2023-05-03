#!/usr/bin/env bash

case "$@" in
    "poweroff")
        poweroff;;
    "reboot")
        reboot;;
    "lock")
        swaylock
        exit 0;;
    "")
        ;;
    *)
        exit 0;;
esac

echo "poweroff"
echo "reboot"
echo "lock"
