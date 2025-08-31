#!/usr/bin/env bash

# --- Ikoner (kräver Nerd Fonts) ---
ICON_CPU=""
ICON_MEM="\uefc5 "
ICON_GPU="﬙"
ICON_TEMP=""
ICON_FAN=""
ICON_DISK=""

# --- Funktioner för att hämta data ---

get_cpu_usage() {
    cpu_idle=$(LC_ALL=C mpstat 1 1 | awk '/Average/ {print $12}')
    cpu_usage=$(echo "scale=0; (100 - $cpu_idle) / 1" | bc)
    echo "$cpu_usage"
}

get_mem_usage() {
    awk '
        /MemTotal/ {total=$2}
        /MemAvailable/ {available=$2}
        END {
            if (total > 0) {
                used = total - available
                printf "%.0f", (used / total) * 100
            } else {
                print "0"
            }
        }
    ' /proc/meminfo
}

get_gpu_usage() {
    if command -v nvidia-smi &> /dev/null; then
        gpu_usage=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits | awk '{print $1}')
        echo "$gpu_usage"
    elif [ -f /sys/class/drm/card0/device/gpu_busy_percent ]; then
        gpu_usage=$(cat /sys/class/drm/card0/device/gpu_busy_percent)
        echo "$gpu_usage"
    else
        echo "N/A"
    fi
}

get_cpu_temp() {
    cpu_temp=$(sensors | grep 'Package id 0' | awk '{print $4}' | sed 's/+//;s/°C//')
    echo "$cpu_temp"
}

# KORRIGERAD FUNKTION: Hanterar system med flera sensorer (hwmon*) korrekt.
get_gpu_temp() {
    if command -v nvidia-smi &> /dev/null; then
        gpu_temp=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits)
        echo "$gpu_temp"
    # Skapar en array 'files' av alla matchande sökvägar.
    # Kollar sedan om det första elementet i arrayen är en giltig fil.
    elif files=(/sys/class/hwmon/hwmon*/temp1_input); [[ -f "${files[0]}" ]]; then
        # Läser endast från den FÖRSTA filen som hittades.
        gpu_temp=$(cat "${files[0]}" | awk '{print $1/1000}')
        echo "$gpu_temp"
    else
        echo "N/A"
    fi
}

get_fan_speed() {
    fan_speed=$(sensors | grep -i 'fan' | awk '{print $2}' | head -n1)
    if [[ -n "$fan_speed" ]]; then
        echo "$fan_speed RPM"
    else
        echo "N/A"
    fi
}

get_disk_usage() {
    df -kP / | awk 'NR==2 {
        pcent = $5;
        used_gb = $3 / 1024 / 1024;
        total_gb = $2 / 1024 / 1024;
        printf "%s (%.1fG/%.1fG)", pcent, used_gb, total_gb
    }'
}

# --- Huvudlogik ---

# Hämta all data
CPU_USAGE=$(get_cpu_usage)
MEM_USAGE=$(get_mem_usage)
GPU_USAGE=$(get_gpu_usage)
CPU_TEMP=$(get_cpu_temp)
GPU_TEMP=$(get_gpu_temp)
FAN_SPEED=$(get_fan_speed)
DISK_USAGE=$(get_disk_usage)

# Bestäm vilken resurs som är mest stressad
max_usage=$CPU_USAGE
icon=$ICON_CPU

if [[ "$(echo "$MEM_USAGE > $max_usage" | bc -l)" == "1" ]]; then
    max_usage=$MEM_USAGE
    icon=$ICON_MEM
fi

if [[ "$GPU_USAGE" != "N/A" && "$(echo "$GPU_USAGE > $max_usage" | bc -l)" == "1" ]]; then
    icon=$ICON_GPU
fi

# Skapa tooltip-text
TOOLTIP="$ICON_CPU CPU: $CPU_USAGE% ($CPU_TEMP°C)\n"
TOOLTIP+="$ICON_MEM Minne: $MEM_USAGE%\n"
if [[ "$GPU_USAGE" != "N/A" ]]; then
    TOOLTIP+="$ICON_GPU GPU: $GPU_USAGE% ($GPU_TEMP°C)\n"
fi
TOOLTIP+="$ICON_FAN Fläkt: $FAN_SPEED\n"
TOOLTIP+="$ICON_DISK SSD: $DISK_USAGE"

# Skriv ut JSON för Waybar
printf '{"text": "%s", "tooltip": "%s"}\n' "$icon" "$TOOLTIP"