# Plats: modules/home/anders.nix
{ config, pkgs, ... }:

{
  # Detta är nödvändigt för att Home Manager ska veta vem du är.
  home.username = "anders";
  home.homeDirectory = "/home/anders";

  home.packages = with pkgs; [
    cowsay # Ett roligt testpaket
  ];

  # Detta är den deklarativa motsvarigheten till att redigera ~/.gitconfig
  programs.git = {
    enable = true;
    userName = "Anders Hardenborg";
    userEmail = "anders.hardenborg@gmail.com";
  };

  # Aktivera bash-hantering (skapar en grundläggande .bashrc)
  programs.bash.enable = true;

  # Du måste ange en state version för Home Manager också.
  # Detta hjälper till att hantera bakåtkompatibilitet.
  home.stateVersion = "25.05";
}