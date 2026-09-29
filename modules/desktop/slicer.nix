{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    cura-appimage
    prusa-slicer
  ];

}
