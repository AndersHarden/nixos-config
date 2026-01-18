# Plats: modules/desktop/hyprland.nix (REN SYSTEM-MODUL)
{ pkgs, ... }:
{
  # Installera system-paket som behövs för en Hyprland-miljö
  # Notera: hyprpaper och andra användarprogram är borttagna härifrån
  environment.systemPackages = with pkgs; [
    rofi
    dunst
    pavucontrol
    brightnessctl
    hyprpicker
    hyprcursor
    blueman
    nwg-look
    graphite-gtk-theme
    kora-icon-theme
  ];
}