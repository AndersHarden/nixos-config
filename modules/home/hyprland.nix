# ./modules/home/hyprland.nix
{ config, pkgs, specialArgs, ... }:
let
  hostName = specialArgs.hostName;
  # Import the base configuration as a string
  baseConfig = builtins.readFile /etc/hypr/hyprland-base.conf;
  # Import the host-specific configuration
  hostConfig = builtins.readFile /etc/hypr/hyprland-${hostName}.conf;
in
{
  wayland.windowManager.hyprland = {
    enable = true;
    # Use extraConfig to combine the base and host-specific configurations
    extraConfig = ''
      ${baseConfig}
      ${hostConfig}
    '';
  };
}