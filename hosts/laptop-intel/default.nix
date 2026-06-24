{ pkgs, inputs, lib, pkgsUnstable, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/hardware/intel.nix
    ../../modules/hardware/laptop.nix
    ../../modules/common/base.nix
    ../../modules/common/utils.nix
    ../../modules/profiles/desktop.nix
    ../../modules/profiles/services.nix
    ./hyprland.nix
    ../../modules/desktop/wine.nix
  ];
 
  networking.hostName = "laptop-intel";
  console.keyMap = "sv-latin1";

  nix.settings = {
    download-buffer-size = 536870912;
    max-jobs = "auto";
    cores = 0;
  };

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
  };

  # Overlay för instabila paket (pekar på central import från flake.nix)
  nixpkgs.overlays = [
    (final: prev: {
      unstable = pkgsUnstable;
    })
  ];

  environment.systemPackages = with pkgs; [
    android-tools
    pkgsUnstable.blender
    calibre
    pkgsUnstable.opencode
  ];

  services.flatpak.enable = true;

  system.stateVersion = "26.05";
}