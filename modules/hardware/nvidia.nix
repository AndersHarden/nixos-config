{ config, pkgs, lib, ... }:
{
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.graphics.enable = true;
  hardware.nvidia.modesetting.enable = true;
  hardware.nvidia.open = false;
  hardware.nvidia.package = lib.mkDefault pkgs.linuxPackages_6_12.nvidiaPackages.legacy_580;

  # egl-wayland2 fixar GTK tooltip/popup-issues på NVIDIA Wayland
  hardware.graphics.extraPackages = [ pkgs.egl-wayland2 ];

  environment.systemPackages = with pkgs; [
    gcc-unwrapped
  ];
}
