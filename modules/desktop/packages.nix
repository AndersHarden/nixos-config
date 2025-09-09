# Plats: modules/desktop/packages.nix
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    kitty                   # A fast, feature-rich, GPU based terminal emulator
    imagemagick             # Software suite to create, edit, compose, or convert bitmap images
    rofi-wayland            # A window switcher, application launcher and dmenu replacement
    dunst                   # A lightweight notification daemon
    jq                      # Command-line JSON processor
    pavucontrol             # PulseAudio Volume Control
    playerctl               # A command-line utility for controlling media players
    brightnessctl           # Utility to control device brightness
    hyprpaper               # Set wallpapers in Hyprland
    hyprpicker              # A color picker for Hyprland
    hypridle                # A lightweight screen locker for Hyprland
    hyprcursor              # A cursor theme switcher for Hyprland
    pywal16                 # A tool to generate and change color schemes on the fly
    nwg-look                # A GTK theme and icon set manager
    graphite-gtk-theme      # A dark GTK theme
    kora-icon-theme         # A colorful icon theme
    blueman                 # A GTK+ Bluetooth Manager
    unstable.waybar         # A highly customizable status bar for Wayland
    eww                     # A widget system for creating desktop widgets
    gtk3                    # GIMP Toolkit for creating graphical user interfaces
    glib                    # Low-level core library that forms the basis for projects such as GTK and GNOME
    gdk-pixbuf              # An image loading library
    pango                   # A library for laying out and rendering text
    cairo                   # A 2D graphics library with support for multiple output devices
    librsvg                 # A library to render SVG files using Cairo
    gtk-layer-shell         # A library for creating GTK toplevels that behave like native Wayland surfaces
    dart-sass               # An implementation of Sass in Dart
    pywalfox-native         # A Firefox extension to change the theme based on pywal colors
  ];
}