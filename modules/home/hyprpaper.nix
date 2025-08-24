# Plats: modules/home/hyprpaper.nix
{ ... }:
{
  home.file.".config/hypr/hyprpaper.conf" = {
    text = ''
      # Denna fil hanteras av NixOS.
      # Vi behöver bara en grundläggande inställning för att
      # hyprpaper ska starta korrekt.
      # Bakgrundsbilder sätts dynamiskt av set-random-wallpaper-skriptet.

      preload = ~/.config/default-wallpaper.jpg
      wallpaper = ,~/.config/default-wallpaper.jpg
    '';
  };
}
