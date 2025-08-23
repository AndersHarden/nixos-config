{ config, lib, pkgs, ... }:
{
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    libGL
    xorg.libX11
    xorg.libXrender
    xorg.libXxf86vm
    xorg.libXfixes
    xorg.libXi
    libxkbcommon
    xorg.libSM
    xorg.libICE
    xorg.libXrandr
    xorg.libXcursor
    xorg.libXinerama
    # Add any missing dynamic libraries for unpackaged programs
    # here, NOT in environment.systemPackages
  ];

}
