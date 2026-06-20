{ config, pkgs, ... }:

{
  programs.rofi = {
    enable = true;
    package = pkgs.rofi;
  };

  xdg.configFile."rofi" = {
    source = ./rofi;
    force = true;
  };
}
