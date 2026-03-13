{ pkgs, inputs, lib, ... }:

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

  # tailored blender for intel + opencode
  environment.systemPackages = with pkgs; [
    unstable.blender
    calibre
    unstable.opencode
  ];

  programs.adb.enable = true;

  services.flatpak.enable = true;

  nixpkgs.overlays = [
    (final: prev: {
      unstable = import inputs.nixpkgs-unstable {
        system = prev.system;
        config.allowUnfree = true;
      };
    })
  ];

  system.stateVersion = "25.11";
}