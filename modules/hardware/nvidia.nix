{ config, pkgs, lib, ... }:
{
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.graphics.enable = true;
  hardware.nvidia.modesetting.enable = true;
  hardware.nvidia.open = false;
  hardware.nvidia.package = lib.mkDefault config.boot.kernelPackages.nvidiaPackages.stable;
  environment.systemPackages = with pkgs; [
    gcc-unwrapped
  ];
}