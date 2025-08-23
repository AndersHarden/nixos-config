{ config, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    orca-slicer
    cura-appimage
    prusa-slicer
  ];

}
