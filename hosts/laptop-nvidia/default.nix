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

  # Overlay för instabila paket (pekar på central import från flake.nix)
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
    max-jobs = "auto";
    cores = 0;
  };

  services.flatpak.enable = true;

  system.stateVersion = "26.05";
}
