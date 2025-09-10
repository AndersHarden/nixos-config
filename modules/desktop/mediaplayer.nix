{ config, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    plexamp
    plex-desktop
    mpv
    vlc
    yt-dlp
  ];

}
