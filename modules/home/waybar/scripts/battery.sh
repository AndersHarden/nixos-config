#!/usr/bin/env bash

# Hitta det första batteriet
BATTERY_PATH=$(find /sys/class/power_supply/ -name 'BAT*' | head -n 1)

if [ -z "$BATTERY_PATH" ]; then
    printf '{"text": " N/A", "tooltip": "Inget batteri hittades", "class": "critical"}\n'
    exit 0
fi

# Hämta grundläggande information
capacity=$(cat "${BATTERY_PATH}/capacity")
status=$(cat "${BATTERY_PATH}/status")

# --- NERD FONT IKONER ---
ICON_CHARGING=''
ICON_FULL=''
ICON_EMPTY=''
ICON_HALF=''
ICON_QUARTER=''
ICON_THREE_QUARTERS=''
ICON_PLUGGED=''

# --- LOGIK FÖR IKONER OCH KLASSER ---
# (Denna del är oförändrad)
if [[ "$status" = "Charging" ]]; then
    icon=$ICON_CHARGING
    class="charging"
elif [[ "$status" = "Full" || ("$status" = "Not charging" && "$capacity" -eq 100) ]]; then
    icon=$ICON_FULL
    class="full"
else
    class="discharging"
    if [[ "$capacity" -le 10 ]]; then
        icon=$ICON_EMPTY
        class="critical"
    elif [[ "$capacity" -le 35 ]]; then
        icon=$ICON_QUARTER
        class="warning"
    elif [[ "$capacity" -le 65 ]]; then
        icon=$ICON_HALF
    elif [[ "$capacity" -le 90 ]]; then
        icon=$ICON_THREE_QUARTERS
    else
        icon=$ICON_FULL
    fi
    if [[ "$status" = "Not charging" ]]; then
        icon=$ICON_PLUGGED
    fi
fi

# --- FÖRBÄTTRAD LOGIK FÖR STRÖMFÖRBRUKNING OCH TOOLTIP ---
upower_info=$(upower -i /org/freedesktop/UPower/devices/battery_$(basename $BATTERY_PATH))
time_remaining=$(echo "$upower_info" | grep -E "time to empty|time to full" | awk '{print $4, $5}')

# Försök först läsa energy-rate direkt
power_draw_raw=$(echo "$upower_info" | grep "energy-rate" | awk '{print $2}')

# Om energy-rate är 0.00 eller tom, försök beräkna manuellt
if [[ -z "$power_draw_raw" || "$power_draw_raw" == "0" ]]; then
    voltage=$(echo "$upower_info" | grep "voltage" | awk '{print $2}')
    current=$(echo "$upower_info" | grep "current" | awk '{print $2}') # Kan heta "current (now)"
    
    # Kontrollera att vi har värden att räkna med
    if [[ -n "$voltage" && -n "$current" ]]; then
        # Använd 'bc' för flyttalsberäkning
        power_draw_calc=$(echo "$voltage * $current" | bc)
        power_draw=$(printf "%.2f W" "$power_draw_calc")
    else
        power_draw="0.00 W" # Fallback om vi inte kan beräkna
    fi
else
    power_draw=$(printf "%.2f W" "$power_draw_raw")
fi

# Bygg variablerna för text och tooltip
text_output="${icon} ${capacity}%"
tooltip_output="Status: ${status}\nTid kvar: ${time_remaining:-N/A}\nTotal förbrukning: ${power_draw:-N/A}"

# Skriv ut JSON med printf
printf '{"text": "%s", "tooltip": "%s", "class": "%s", "percentage": %d}\n' \
    "$text_output" \
    "$tooltip_output" \
    "$class" \
    "$capacity"