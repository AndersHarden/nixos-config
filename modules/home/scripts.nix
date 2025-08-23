{ pkgs, ... }:
{
  home.file.".local/bin/set-random-wallpaper" = { # Vi ger det ett tydligt namn
    source = ./scripts/set-wallpaper.sh;
    executable = true;
  };
}