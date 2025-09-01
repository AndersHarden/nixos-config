# ./modules/home/hyprpaper.nix
{ config, pkgs, specialArgs, ... }:

let
  hostName = specialArgs.hostName; # Extract hostName from specialArgs
in
{
  # Ensure hyprpaper is installed for the user
  home.packages = with pkgs; [ hyprpaper ];

  # Create hyprpaper configuration
  xdg.configFile."hypr/hyprpaper.conf".text = ''
    # Hyprpaper configuration managed by Home Manager
    preload = /home/anders/.config/default-wallpaper.jpg
    wallpaper = ,/home/anders/.config/default-wallpaper.jpg
  '';
}