# Plats: modules/desktop/hyprland-base.nix
{ config, pkgs, ... }:

let
  # Definiera den generella Hyprland-konfigurationen i Lua-format
  # för Hyprland 0.55+
  hyprlandBaseConfig = import ./hyprland-base-lua.nix;
in
{
  # Aktivera system-stödet för Hyprland
  programs.hyprland.enable = true;

  # Skriv den generella konfigurationen till /etc/hypr/hyprland-base.conf
  environment.etc."hypr/hyprland-base.conf".text = hyprlandBaseConfig;
}
