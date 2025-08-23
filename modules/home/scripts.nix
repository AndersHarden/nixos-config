# Plats: modules/home/scripts.nix
{ pkgs, ... }:
{
  home.file.".config/Scripts/wallpaper-changer.sh" = {
    source = ./scripts/wallpaper-changer.sh;
    executable = true; # Gör skriptet körbart!
  };
  # Gör likadant för battery-notify och dina rofi-skript
}