# Plats: ~/nixos-config/modules/home/anders.nix (REN, FRISTÅENDE HM-MODUL)
{ config, pkgs, ... }:

{
  # Importerar andra Home Manager-moduler
  imports = [
    ./kitty.nix
    ./waybar.nix
    ./scripts.nix
    ./config-files.nix
    ./hyprpaper.nix
    ./hyprland.nix
    ./pywal.nix
  ];

  # Grundläggande information
  home.username = "anders";
  home.homeDirectory = "/home/anders";
  home.stateVersion = "24.05"; # Korrekt version

  # PATH och profil (detta är ett giltigt HM-alternativ)
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