{ pkgs, ... }:
{
  services.xserver.videoDrivers = [ "intel" ];
  hardware.graphics.enable = true;
  # Intel specific packages
  environment.systemPackages = with pkgs; [ 
    unstable.blender
  ];
}