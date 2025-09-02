# ./modules/home/hyprland.nix
{ config, pkgs, specialArgs, ... }:
let
  hostName = specialArgs.hostName;
  baseConfig = specialArgs.systemEtc."hypr/hyprland-base.conf".text;
  hostConfig = specialArgs.systemEtc."hypr/hyprland-${hostName}.conf".text;
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