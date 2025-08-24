# Plats: modules/desktop/hyprland.nix (REN SYSTEM-MODUL)
{ config, pkgs, inputs, ... }:
{
  # Denna fils enda ansvar är att aktivera system-modulen för Hyprland.
  programs.hyprland.enable = true;
}