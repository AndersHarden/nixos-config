{ config, pkgs, ... }:

{
  programs.waybar = {
    enable = true;
    # du kan lägga in konfig här, eller använda `xdg.configFile`
  };

  xdg.configFile."waybar/config".source = ./waybar/config.jsonc;
  xdg.configFile."waybar/style.css".source = ./waybar/style.css;

  home.packages = with pkgs; [ jq ]; # ex. om du behöver extra paket
}