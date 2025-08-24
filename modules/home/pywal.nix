# Plats: ~/nixos-config/modules/home/pywal.nix
{ pkgs, ... }:

{
  # Detta är en ren Home Manager-modul.
  # Den aktiverar pywal och definierar vilka mallar som ska genereras
  # när 'wal' körs.
  programs.pywal = {
    enable = true;

    # 'templates' talar om för pywal att den ska ta en mallfil,
    # fylla i färgerna, och spara resultatet på en specifik plats.
    templates = {
      # Nyckeln "waybar/style.css" betyder att resultatet ska sparas som
      # ~/.config/waybar/style.css.
      # Värdet pekar på vår mallfil.
      "waybar/style.css" = builtins.readFile ./waybar/style.css.tmpl;
    };
  };
}