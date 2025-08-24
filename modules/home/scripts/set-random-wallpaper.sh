#!/usr/bin/env bash
# Plats: ~/nixos-config/modules/home/scripts/set-random-wallpaper.sh

set -euo pipefail

DIR_FILE="$HOME/.config/wallpaper_dirs.txt"

if [[ ! -f "$DIR_FILE" ]]; then
    echo "Fel: $DIR_FILE hittades inte." >&2
    exit 1
fi

mapfile -t images < <(
    while IFS= read -r dir; do
        expanded_dir=$(eval echo "$dir")
        if [[ -d "$expanded_dir" ]]; then
            find "$expanded_dir" -type f \( -iname '*.jpg' -o -iname '*.png' \)
        fi
    done < "$DIR_FILE"
)

if [ ''${#images[@]} -eq 0 ]; then
    echo "Inga bilder hittades." >&2
    exit 1
fi

# Använd 'shuf' för att slumpmässigt och robust välja en bild från listan
random_image=$(printf "%s\n" "''${images[@]}" | shuf -n 1)

if [[ -z "$random_image" ]]; then
    echo "Fel: Kunde inte välja en slumpmässig bild." >&2
    exit 1
fi

echo "Vald bakgrund: $random_image"

# Sätt bakgrund
hyprctl hyprpaper unload all
hyprctl hyprpaper preload "$random_image"
hyprctl hyprpaper wallpaper ",$random_image"

# Kör wal och dölj ofarliga varningar
wal -i "$random_image" -q -n 2>/dev/null

# Starta om Waybar på ett robust sätt
pkill -x waybar || true  # Stäng ner befintlig instans, ignorera fel om den inte körs
sleep 0.2               # Ge den tid att stänga ner helt
waybar &                # Starta en ny instans i bakgrunden