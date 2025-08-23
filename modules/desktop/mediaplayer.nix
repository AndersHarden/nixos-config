{ config, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    plexamp
    plex-desktop
    jellyfin-media-player
    mpv
    vlc
    yt-dlp
  ];

}
