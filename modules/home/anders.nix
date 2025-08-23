{ config, pkgs, ... }:

{
  # Importera alla dina program-specifika konfigurationer här
  imports = [
    ./kitty.nix
    ./config-files.nix
  ];

  home.username = "anders";
  home.homeDirectory = "/home/anders";

  home.packages = with pkgs; [
    htop
    neofetch
  ];

  programs.git = {
    enable = true;
    userName = "Anders Hardenborg";
    userEmail = "din-email@exempel.com";
  };

  programs.bash.enable = true;
  home.stateVersion = "25.05";
}