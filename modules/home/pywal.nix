# Plats: modules/home/pywal.nix (REN HM-MODUL)
{ pkgs, ... }:
{
  programs.pywal = {
    enable = true;
    templates = {
      "waybar/style.css" = builtins.readFile ./waybar/style.css.tmpl;
    };
  };
}