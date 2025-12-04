# Plats: modules/desktop/packages.nix
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    # Detta är alla paket som tidigare låg i hyprland.nix
    kitty
    imagemagick
    rofi
    dunst
    jq
    pavucontrol
    playerctl
    brightnessctl
    hyprpaper # Installeras på systemnivå för att 'exec-once' ska hitta den
    hyprpicker
    hypridle
    hyprcursor
    pywal16
    nwg-look
    graphite-gtk-theme
    kora-icon-theme
    blueman
    unstable.waybar
    eww
    gtk3
    glib
    gdk-pixbuf
    pango
    cairo
    librsvg
    gtk-layer-shell
    dart-sass
    pywalfox-native
  ];
}