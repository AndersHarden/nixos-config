#!/usr/bin/env bash

DIR_FILE="$HOME/wallpaper_dirs.txt"
WAYBAR_STYLE="$HOME/.config/waybar/style.css"
COLOR_CACHE="$HOME/.cache/wallpaper-changer-last-color"

# Läs in bilder (expandera ~ och hantera mellanslag)
mapfile -t images < <(
    while read -r dir; do
        expanded_dir=$(eval echo "$dir")
        [ -d "$expanded_dir" ] && find "$expanded_dir" -type f \( -iname '*.jpg' -o -iname '*.png' \)
    done < "$DIR_FILE"
)

if [ ${#images[@]} -eq 0 ]; then
    echo "Inga bilder hittades."
    exit 1
fi

pick_wallpaper() {
    local img="$1"

    # Sätt bakgrund med hyprpaper
    hyprctl hyprpaper unload all
    hyprctl hyprpaper preload "$img"
    hyprctl hyprpaper wallpaper ,"$img"

    # Analysera övre 20% av bilden för ljushet (0-255)
    brightness=$(magick "$img" -crop x20%+0+0 -resize 1x1 -colorspace gray -format "%[fx:255*p{0,0}]" info:)

    # Välj textfärg och tooltip bakgrund
    if (( $(echo "$brightness > 128" | bc -l) )); then
        color="#000000"          # ljus bakgrund → svart text
        tooltip_bg="rgba(255,255,255,0.85)"  # ljus tooltip bakgrund
    else
        color="#ffffff"          # mörk bakgrund → vit text
        tooltip_bg="rgba(0,0,0,0.85)"        # mörk tooltip bakgrund
    fi

    # Läs föregående färg om finns
    last_color=""
    last_tooltip_bg=""
    if [ -f "$COLOR_CACHE" ]; then
        read -r last_color last_tooltip_bg < "$COLOR_CACHE"
    fi

    # Byt bara om något ändrats
    if [ "$color" != "$last_color" ] || [ "$tooltip_bg" != "$last_tooltip_bg" ]; then
        sed -i "s/color: *#[0-9a-fA-F]\{6\}/color: $color/" "$WAYBAR_STYLE"
        sed -i "s/background-color: rgba([^)]*)/background-color: $tooltip_bg/" "$WAYBAR_STYLE"

        echo "$color $tooltip_bg" > "$COLOR_CACHE"

        # Fade-animation
        if command -v waybar-msg >/dev/null 2>&1; then
            waybar-msg cmd '{"opacity": 0.0}'
            sleep 0.15
            waybar-msg cmd '{"opacity": 1.0}'
        else
            pkill -SIGUSR2 waybar
        fi
    fi
}


if [[ "$1" == "--random" ]]; then
    interval="${2:-600}" # default 10 min
    while true; do
        pick_wallpaper "${images[RANDOM % ${#images[@]}]}"
        sleep "$interval"
    done
else
    # Skapa lista med bara filnamn
    declare -a names
    for f in "${images[@]}"; do
        names+=("$(basename "$f")")
    done

    # Visa rofi-meny med snygg styling och scroll
    choice=$(printf '%s\n' "${names[@]}" | rofi -dmenu -i -p "Välj bakgrund" \
        -theme-str 'window {width: 400px; border-radius: 10px;} listview {columns: 1; lines: 10;} element {padding: 8px;} element selected {background: #005577; color: white;}')

    # Matcha valet mot full sökväg
    img=""
    for i in "${!names[@]}"; do
        if [[ "${names[i]}" == "$choice" ]]; then
            img="${images[i]}"
            break
        fi
    done

    [ -n "$img" ] && pick_wallpaper "$img"
fi
