{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    slack
    discord
    unstable.telegram-desktop
  ];

}
