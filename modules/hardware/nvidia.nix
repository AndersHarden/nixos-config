{ pkgs, ... }:
{
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.graphics.enable = true;
  hardware.nvidia.modesetting.enable = true;
  hardware.nvidia.open = false;
  hardware.nvidia.package = pkgs.linuxPackages_6_12.nvidiaPackages.stable;
  environment.systemPackages = with pkgs; [
    gcc-unwrapped
  ];
}