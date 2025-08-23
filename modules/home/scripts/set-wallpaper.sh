#!/usr/bin/env bash
# Plats: modules/home/scripts/set-wallpaper.sh

# Sökväg till filen som listar dina mappar
DIR_FILE="$HOME/.config/wallpaper_dirs.txt"

# Kontrollera att filen finns
if [ ! -f "$DIR_FILE" ]; then
    echo "Fel: $DIR_FILE hittades inte." >&2
    exit 1
fi

# Läs in alla bildfiler från alla mappar som listas i DIR_FILE
# Detta hanterar sökvägar med ~ och mellanslag korrekt.
mapfile -t images < <(
    while read -r dir; do
        # Expandera tilde (~) och variabler
        expanded_dir=$(eval echo "$dir")
        # Hitta alla jpg- och png-filer i den expanderade mappen
        if [ -d "$expanded_dir" ]; then
            find "$expanded_dir" -type f \( -iname '*.jpg' -o -iname '*.png' \)
        fi
    done < "$DIR_FILE"
)

# Kontrollera att vi hittade några bilder
if [ ''${#images[@]} -eq 0 ]; then
    echo "Inga bilder hittades i mapparna som specificerats i $DIR_FILE." >&2
    exit 1
fi

# Välj en slumpmässig bild från listan
random_image="''${images[RANDOM % ''${#images[@]}]}"

echo "Vald bakgrund: $random_image"

# --- Huvudlogiken ---
# 1. Sätt bakgrundsbilden med hyprpaper
hyprctl hyprpaper unload all
hyprctl hyprpaper preload "$random_image"
hyprctl hyprpaper wallpaper ,"$random_image"

# 2. Kör wal för att generera nya färgscheman från bilden
#    -i pekar på bilden
#    -q gör den tyst
#    -n hoppar över att sätta terminalfärger (valfritt, men snabbare)
wal -i "$random_image" -q -n

# 3. Ladda om Waybar för att applicera den nya style.css
#    SIGUSR2 är signalen för att ladda om stilen
pkill -SIGUSR2 waybar