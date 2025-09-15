{ config, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    quickemu
    quickgui
    qemu
  ];

}
