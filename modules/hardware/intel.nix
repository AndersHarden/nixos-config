{ pkgs, ... }:
{
  services.xserver.videoDrivers = [ "intel" ];
  hardware.graphics.enable = true;
}