# Plats: modules/home/config-files.nix
{ pkgs, ... }:
{
  # Detta block talar om för Home Manager att skapa filen
  # ~/.config/wallpaper_dirs.txt och att dess innehåll ska
  # komma från filen vi skapade i vår config-mapp.
  home.file.".config/wallpaper_dirs.txt" = {
    source = ./config-files/wallpaper_dirs.txt;
  };
}