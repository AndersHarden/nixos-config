# ./modules/home/hyprland.nix
{ config, pkgs, specialArgs, ... }:
let
  hostName = specialArgs.hostName;
  # Access the base and host-specific configurations from the system environment
  baseConfig = config.environment.etc."hypr/hyprland-base.conf".text;
  hostConfig = config.environment.etc."hypr/hyprland-${hostName}.conf".text;
in
{
  # Enable Home Manager's Hyprland module
  wayland.windowManager.hyprland = {
    enable = true;
    extraConfig = ''
      ${baseConfig}
      ${hostConfig}
    '';
  };
}