{ config, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    plexamp
    plex-desktop
    jellyfin-desktop
    mpv
    vlc
    yt-dlp
  ];

}
