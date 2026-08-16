{ config, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    firefox
    google-chrome
    chromium
    chromedriver
    brave
  ];

}
