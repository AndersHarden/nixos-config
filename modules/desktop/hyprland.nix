# Plats: modules/desktop/hyprland.nix
{ config, pkgs, ... }:

# Hela 'let'-blocket är borttaget.
# Denna modul är nu "ren" och förlitar sig på att värd-filen
# tillhandahåller 'pkgs.unstable' via en overlay.
{
  # Aktivera Hyprland och relaterade tjänster
  programs.hyprland.enable = true;
  services.hypridle.enable = true;
  programs.hyprlock.enable = true;

  # Paket som ska installeras för Hyprland-miljön
  environment.systemPackages = with pkgs; [
    # Terminal och grundläggande verktyg
    kitty
    imagemagick
    rofi-wayland
    dunst
    jq

    # Ljud, media och skärm-kontroller
    pavucontrol
    playerctl
    brightnessctl

    # Hyprland-specifika verktyg
    hyprpaper
    hyprpicker
    hyprcursor

    # Teman och utseende
    pywal16
    nwg-look
    graphite-gtk-theme
    kora-icon-theme

    # Bluetooth
    blueman

    # Waybar och dess beroenden
    unstable.waybar # Använder 'unstable' direkt från pkgs-overlay
    eww
    gtk3
    glib
    gdk-pixbuf
    pango
    cairo
    librsvg
    gtk-layer-shell
    dart-sass

    # =================================================================
    # == INNEHÅLL FRÅN waybar-network-vnstat.nix INTEGRERAT HÄR      ==
    # =================================================================
    (writeShellScriptBin "waybar-network-vnstat" ''
      #!/usr/bin/env bash
      set -euo pipefail

      while true; do
        # ── Interface ─────────────────────
        IFACE=$(ip -o -4 addr show up | awk '!/ lo / {print $2; exit}')
        [ -z "$IFACE" ] && IFACE="wlan0"

        # ── IP och Wi-Fi info ─────────────
        IPADDR=$(ip -4 addr show dev "$IFACE" 2>/dev/null | awk '/inet /{print $2}' | cut -d/ -f1 || echo "N/A")

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

        FREQ="N/A"
        if command -v iw >/dev/null 2>&1 && [ "$IS_WIFI" -eq 1 ]; then
          FREQ=$(iw dev "$IFACE" info 2>/dev/null | awk '/channel/ {print $2 " MHz"}' || echo "N/A")
        fi

        # ── vnstat parsing ────────────────
        TODAY="N/A"
        YESTERDAY="N/A"
        MONTH="N/A"

        VNDUMP=$(vnstat -i "$IFACE" 2>/dev/null || true)

        if [ -n "$VNDUMP" ]; then
          TODAY=$(echo "$VNDUMP" | awk '/^ *today/ {print $2 " " $3 " / " $5 " " $6}')
          YESTERDAY=$(echo "$VNDUMP" | awk '/^ *yesterday/ {print $2 " " $3 " / " $5 " " $6}')
          MONTH=$(echo "$VNDUMP" | awk '/^[0-9]{4}-[0-9]{2}/ {print $2 " " $3 " / " $5 " " $6; exit}' || echo "N/A")
        fi

        # ── Ikon ──────────────────────────
        ICON=""
        if [ -n "$IPADDR" ] && [ "$IPADDR" != "N/A" ]; then
          if [ "$IS_WIFI" -eq 1 ]; then
            ICON=""
          else
            ICON=""
          fi
        fi

        # ── JSON till Waybar ──────────────
        TEXT_JSON=$(echo -n "$ICON  $ESSID" | jq -Rs .)
        TOOLTIP_JSON=$(echo -e "Interface: $IFACE\nIP: $IPADDR\nSignal: $SIGNAL%\nFreq: $FREQ\n\nToday: $TODAY\nYesterday: $YESTERDAY\nMonth: $MONTH" | jq -Rs .)

        printf '{"text":%s,"tooltip":%s,"class":"net"}\n' "$TEXT_JSON" "$TOOLTIP_JSON"
        sleep 5  # Uppdatera var 5:e sekund
      done
    '' // {
      # Beroenden som behövs för att köra skriptet
      nativeBuildInputs = [ iproute2 iw vnstat jq ];
    })
  ];
}