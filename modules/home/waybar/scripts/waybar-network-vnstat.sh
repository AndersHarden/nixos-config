#!/usr/bin/env bash
set -euo pipefail

# Hitta första aktiva interface
IFACE=$(ip -o -4 addr show up | awk '!/ lo / {print $2; exit}')
[ -z "$IFACE" ] && IFACE="wlan0"

# Hämta IP
IPADDR=$(ip -4 addr show dev "$IFACE" 2>/dev/null | awk '/inet /{print $2}' | cut -d/ -f1 || echo "N/A")

# Wi-Fi info
IS_WIFI=0
ESSID=""
if [ -r /proc/net/wireless ] && grep -qE "^[[:space:]]*$IFACE:" /proc/net/wireless; then
    IS_WIFI=1
    ESSID=$(iwgetid "$IFACE" -r 2>/dev/null || echo "")
fi
[ -z "$ESSID" ] && ESSID="$IFACE"

SIGNAL="0"
if [ "$IS_WIFI" -eq 1 ]; then
    SIGNAL=$(grep -E "^[[:space:]]*$IFACE:" /proc/net/wireless | awk '{print int($3 * 100 / 70)}' 2>/dev/null || echo "0")
fi

ICON=$([ "$IS_WIFI" -eq 1 ] && echo "" || echo "")
[ -z "$IPADDR" ] && ICON=""

TEXT_JSON=$(echo -n "$ICON  $ESSID" | jq -Rs .)
TOOLTIP_JSON=$(echo -e "Interface: $IFACE\nIP: $IPADDR\nSignal: $SIGNAL%" | jq -Rs .)

printf '{"text":%s,"tooltip":%s,"class":"net"}\n' "$TEXT_JSON" "$TOOLTIP_JSON"
