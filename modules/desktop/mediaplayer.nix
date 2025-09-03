{ config, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    plexamp
    plex-media-player
    jellyfin-media-player
    mpv
    vlc
    yt-dlp
  ];

}
