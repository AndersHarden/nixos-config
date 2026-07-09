{ pkgs, inputs, lib, pkgsUnstable, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/hardware/nvidia.nix
    ../../modules/hardware/intel.nix
    ../../modules/hardware/laptop.nix
    ../../modules/common/base.nix
    ../../modules/common/utils.nix
    ../../modules/profiles/desktop.nix
    ../../modules/profiles/services.nix
    ./hyprland.nix
  ];

  networking.hostName = "laptop-nvidia";
  console.keyMap = "sv-latin1";

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    kernelPackages = lib.mkForce pkgs.linuxPackages_6_12;
  };

  hardware.nvidia.package = pkgs.linuxPackages_6_12.nvidiaPackages.legacy_470;

  nixpkgs.overlays = [
    (final: prev: {
      unstable = pkgsUnstable;
    })
  ];

  environment.systemPackages = with pkgs; [
    pkgsUnstable.blender
    virt-manager
    pkgsUnstable.opencode
  ];

  nix.settings = {
    download-buffer-size = 268435456;
    max-jobs = 1;
    cores = 0;
  };

  zramSwap.enable = true;
  zramSwap.memoryPercent = 50;

  services.flatpak.enable = true;

  system.stateVersion = "26.05";
}
