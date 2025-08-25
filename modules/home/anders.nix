# Plats: ~/nixos-config/modules/home/anders.nix
{ config, pkgs, ... }:
{
  imports = [
    ./kitty.nix
    ./waybar.nix
    ./scripts.nix
    ./config-files.nix
    ./hyprpaper.nix
    ./hyprland.nix
    ./pywal.nix
  ];

  home.username = "anders";
  home.homeDirectory = "/home/anders";
  home.stateVersion = "24.05";

  # Använd sessionVariables för att sätta $PATH, eftersom det fungerade
  home.sessionVariables = {
    PATH = "$HOME/.local/bin:$HOME/.nix-profile/bin:$PATH";
  };

  home.packages = with pkgs; [
    htop
    neofetch
    cowsay
    pywal
    hyprpaper
    sysstat
  ];

  gtk = {
    enable = true;
    cursorTheme = { name = "Adwaita"; size = 24; };
  };

  programs.git = {
    enable = true;
    userName = "Anders Hardenborg";
    userEmail = "anders.hardenborg@gmail.com";
  };
  programs.bash.enable = true;
}