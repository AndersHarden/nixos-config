{ pkgs, ... }:
{
  services.xserver.videoDrivers = [ "intel" ];
  hardware.opengl.enable = true;
}