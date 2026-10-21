#!/bin/sh
# Dumps saved Wi-Fi connection profiles plus the currently active one.
#
# nmcli's "connection show" only accepts a fixed set of fields, so the SSID,
# interface binding and key management cannot be reported for every profile in
# one call — they have to be queried one profile at a time.
#
# Output is tab separated, one record per line:
#
#   DEV    <wifi device name>
#   CON    <uuid> <ssid> <autoconnect> <priority> <interface-name> <key-mgmt>
#   ACTIVE <uuid of the active wifi profile>
#
# The interface-name field is empty for profiles that are not pinned to a
# specific interface. Profiles pinned to an interface that does not exist on
# this machine (e.g. "wlp3s0" copied over from another box) can never be
# activated, so callers should prefer unpinned profiles for a given SSID.

nm_dev=$(nmcli -t -f GENERAL.DEVICE,GENERAL.TYPE device show 2>/dev/null \
    | awk -F: '$1=="GENERAL.DEVICE" && $2!="" {print $2; exit}')
[ -n "$nm_dev" ] || nm_dev=$(nmcli -t -f DEVICE,TYPE device show 2>/dev/null \
    | awk -F: '$2=="wifi"{print $1; exit}')
printf 'DEV\t%s\n' "$nm_dev"

# autoconnect and priority are available for all profiles at once.
nmcli -t -f UUID,TYPE,AUTOCONNECT,AUTOCONNECT-PRIORITY connection show 2>/dev/null \
    | awk -F: '$2=="802-11-wireless"{print $1"\t"$3"\t"$4}' \
    | while IFS="$(printf '\t')" read -r uuid autoconnect priority; do
        [ -n "$uuid" ] || continue
        ssid=$(nmcli -g 802-11-wireless.ssid connection show "$uuid" 2>/dev/null)
        iface=$(nmcli -g connection.interface-name connection show "$uuid" 2>/dev/null)
        keymgmt=$(nmcli -g 802-11-wireless-security.key-mgmt connection show "$uuid" 2>/dev/null)
        printf 'CON\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$uuid" "$ssid" "$autoconnect" "$priority" "$iface" "$keymgmt"
    done

nmcli -t -f ACTIVE,UUID,TYPE connection show 2>/dev/null \
    | awk -F: '$1=="yes" && $3=="802-11-wireless"{print "ACTIVE\t"$2}'
