#!/usr/bin/env bash
# ~/nixos-config/modules/home/scripts/set-random-wallpaper.sh

set -euo pipefail

DIR_FILE="$HOME/.config/wallpaper_dirs.txt"
if [[ ! -f "$DIR_FILE" ]]; then
    echo "Fel: $DIR_FILE hittades inte." >&2
    exit 1
fi

# Läs in bilder
mapfile -t images < <(
    while IFS= read -r dir; do
        expanded_dir=$(eval echo "$dir")
        if [[ -d "$expanded_dir" ]]; then
            find "$expanded_dir" -type f \( -iname '*.jpg' -o -iname '*.png' \)
        fi
    done < "$DIR_FILE"
)

if [[ ${#images[@]} -eq 0 ]]; then
    echo "Inga bilder hittades." >&2
    exit 1
fi

# Slumpa fram en bild
random_image=$(printf "%s\n" "${images[@]}" | shuf -n 1)
echo "Vald bakgrund: $random_image"

# Sätt bakgrund via hyprpaper
hyprctl hyprpaper unload all
hyprctl hyprpaper preload "$random_image"
hyprctl hyprpaper wallpaper ",$random_image"

# Kör wal utan output
wal -i "$random_image" -q -n 2>/dev/null || true

# ===== Waybar färg baserat på övre 5% av bilden =====
if command -v convert &>/dev/null; then
    top_crop=$(identify -format "%[fx:h*0.05]" "$random_image" | cut -d. -f1)
    top_crop=$(( top_crop > 0 ? top_crop : 1 ))

    # Hämta snittfärg för övre 5%
    read r g b < <(convert "$random_image" -crop "100%x$top_crop+0+0" \
        -resize 1x1 -format "%[fx:int(255*r)] %[fx:int(255*g)] %[fx:int(255*b)]" info:)

    # WCAG brightness-formel
    brightness=$(echo "0.299*$r + 0.587*$g + 0.114*$b" | bc)

    echo "RGB: ($r,$g,$b) → brightness $brightness"

    if (( ${brightness%.*} > 150 )); then
        text_color="#000000"
    else
        text_color="#ffffff"
    fi
else
    echo "Imagemagick saknas, använder svart som fallback"
    text_color="#000000"
fi

echo "Waybar-text ska bli: $text_color"

# Waybar CSS – skriv till cache istället för nixos-hanterad config
WAYBAR_CSS="$HOME/.cache/waybar-color.css"
mkdir -p "$(dirname "$WAYBAR_CSS")"
# Anpassa tooltip bakgrund beroende på textfärgen
if [[ "$text_color" == "#000000" ]]; then
    tooltip_bg="#ffffff"  # ljus bakgrund för mörk text
else
    tooltip_bg="#222222"  # mörk bakgrund för ljus text
fi

cat > "$WAYBAR_CSS" <<EOF
* {
  color: $text_color;
}

tooltip {
  color: $text_color;
  background-color: $tooltip_bg;
}
EOF


# Signalera Waybar att läsa om CSS
pkill -SIGUSR2 waybar 2>/dev/null || true
echo "Waybar CSS reload signal skickad"

# ===== Kitty färg =====
KITTY_COLORS="$HOME/.cache/wal/colors-kitty.conf"
if [[ -f "$KITTY_COLORS" ]]; then
    echo "Kitty färger uppdaterade via $KITTY_COLORS"
else
    echo "⚠️ Kitty-färgfil saknas: $KITTY_COLORS"
fi

echo "Wallpaper, Waybar och Kitty-färg uppdaterad."
