# Plats: modules/home/waybar.nix
{ pkgs, ... }:
{
  programs.waybar = {
    enable = true;
    # Denna version hade en felaktig @import-regel, men den byggde.
    # Vi kommer att fixa detta i nästa steg.
    style = builtins.readFile ./waybar/style.css;
    settings = { /* ... din fullständiga settings ... */ };
  };
  home.file = { /* ... dina skript ... */ };
}