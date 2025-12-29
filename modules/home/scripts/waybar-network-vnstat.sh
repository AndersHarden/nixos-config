#!/usr/bin/env bash
set -euo pipefail

# Hitta första aktiva interface (ignorera VM-bridge)
IFACE=$(ip -o -4 addr show up | awk '
  $2 != "lo" &&
  $2 != "tailscale0" &&
  $2 != "virbr0" {print $2; exit}'
)
[ -z "$IFACE" ] && IFACE="wlan0"

# IP-adress
IPADDR=$(ip -4 addr show dev "$IFACE" 2>/dev/null | awk '/inet /{print $2}' | cut -d/ -f1 || echo "N/A")

# Wi-Fi info
IS_WIFI=0
ESSID=""
SIGNAL=""

if [ -r /proc/net/wireless ] && grep -qE "^[[:space:]]*$IFACE:" /proc/net/wireless; then
  IS_WIFI=1
  ESSID=$(iwgetid "$IFACE" -r 2>/dev/null || echo "")
  SIGNAL=$(awk -v iface="$IFACE" '$1 ~ iface":" {print int($3 * 100 / 70)}' /proc/net/wireless)
fi

# Ikon
if [ "$IS_WIFI" -eq 1 ]; then
  ICON="󰤨"
else
  ICON="󰈀"
fi

# vnstat data
TODAY="N/A"
YESTERDAY="N/A"
VNDUMP=$(vnstat -i "$IFACE" 2>/dev/null || true)

if [ -n "$VNDUMP" ]; then
  TODAY=$(echo "$VNDUMP" | awk '/^ *today/ {print $2 " " $3 " / " $5 " " $6}')
  YESTERDAY=$(echo "$VNDUMP" | awk '/^ *yesterday/ {print $2 " " $3 " / " $5 " " $6}')
fi

# JSON till Waybar
TEXT_JSON=$(echo -n "$ICON  $ESSID" | jq -Rs .)
TOOLTIP_JSON=$(echo -e \
"Interface: $IFACE
IP: $IPADDR
Signal: ${SIGNAL:-N/A}%
Today: $TODAY
Yesterday: $YESTERDAY" | jq -Rs .)

printf '{"text":%s,"tooltip":%s,"class":"net"}\n' "$TEXT_JSON" "$TOOLTIP_JSON"
