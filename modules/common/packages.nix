{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    vim
    git
    htop
    fastfetch
    btop
    nautilus
    adwaita-icon-theme
    home-manager
    kdePackages.kate
    sysstat
    sushi
    loupe
    gnome-decoder
    ffmpegthumbnailer
    glance
    gnome-disk-utility
    gnome.gvfs
    udisks2
    ffmpeg
    mp4v2
    zlib
    stdenv.cc.cc.lib
  ];
}
