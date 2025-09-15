{ pkgs, ... }:
{
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.graphics.enable = true;
  hardware.nvidia.modesetting.enable = true;
  hardware.nvidia.open = false;
  # nvidia specific packages
  environment.systemPackages = with pkgs; [ 
    cudaPackages.cudatoolkitg
  ];
}