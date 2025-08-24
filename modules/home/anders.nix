# Plats: ~/nixos-config/modules/home/anders.nix
{ config, pkgs, ... }:

{
  # Importerar andra Home Manager-moduler
  imports = [
    ./kitty.nix
    ./waybar.nix
    ./scripts.nix
    ./config-files.nix
    ./hyprpaper.nix
    ./hyprland.nix # <-- LÄGG TILL DENNA
    ./pywal.nix  
  ];

  # Grundläggande information
  home.username = "anders";
  home.homeDirectory = "/home/anders";
  home.stateVersion = "25.05";

  # PATH och profil (detta kommer att fungera nu)
  home.profile.enable = true;

  # Paket
  home.packages = with pkgs; [
    htop
    neofetch
    cowsay
    pywal
    hyprpaper
    sysstat
  ];

  # GTK-tema för muspekare
  gtk = {
    enable = true;
    cursorTheme = {
      name = "Adwaita";
      size = 24;
    };
  };

  # Programkonfigurationer
  programs.git = {
    enable = true;
    userName = "Anders Hardenborg";
    userEmail = "anders.hardenborg@gmail.com";
  };
  programs.bash.enable = true;
}