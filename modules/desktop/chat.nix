{ config, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    slack
    discord
    telegram-desktop
  ];

}
