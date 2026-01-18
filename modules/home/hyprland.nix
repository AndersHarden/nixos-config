# ./modules/home/hyprland.nix
{ config, pkgs, specialArgs, ... }:
let
  hostName = specialArgs.hostName;
  hasBaseConfig = specialArgs.systemEtc ? "hypr/hyprland-base.conf";
  hasHostConfig = specialArgs.systemEtc ? "hypr/hyprland-${hostName}.conf";
  baseConfig = if hasBaseConfig then specialArgs.systemEtc."hypr/hyprland-base.conf".text else "";
  hostConfig = if hasHostConfig then specialArgs.systemEtc."hypr/hyprland-${hostName}.conf".text else "";
  shouldEnable = hasBaseConfig && hasHostConfig;
in
{
  # Enable Home Manager's Hyprland module only if configs exist
  wayland.windowManager.hyprland = {
    enable = shouldEnable;
    extraConfig = 
      if shouldEnable then ''
        ${baseConfig}
        ${hostConfig}
      '' else "";
  };
}