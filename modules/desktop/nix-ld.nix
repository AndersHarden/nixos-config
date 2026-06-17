{ config, lib, pkgs, ... }:
{
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    libGL
    libx11
    libxrender
    libxxf86vm
    libxfixes
    libxi
    libxkbcommon
    libsm
    libice
    libxrandr
    libxcursor
    libxinerama
  ];

}
