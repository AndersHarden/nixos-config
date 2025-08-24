# Plats: ~/nixos-config/hosts/laptop-intel/default.nix
{ pkgs, inputs, ... }:

{
  imports = [
    # Hårdvara
    ./hardware-configuration.nix
    ../../modules/hardware/intel.nix
    ../../modules/hardware/laptop.nix # Specifika laptop-inställningar

    # Gemensam bas
    ../../modules/common/base.nix
    ../../modules/common/utils.nix

    # Profiler
    ../../modules/profiles/desktop.nix
    # Notera: server.nix är borttagen för ökad säkerhet på en laptop

    # Aktivera Home Manager
    inputs.home-manager.nixosModules.default,

    # Importera din centrala användarkonfiguration
    ../../modules/home/anders.nix
  ];

  # Unika inställningar
  networking.hostName = "laptop-intel";
  console.keyMap = "sv-latin1";

  # LUKS och Bootloader
  boot = {
    initrd.luks.devices."root" = {
      device = "/dev/nvme0n1p5";
      preLVM = true;
    };
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
  };

  # Overlay för instabila paket
  nixpkgs.overlays = [
    (final: prev: {
      unstable = import inputs.nixpkgs-unstable {
        system = prev.system;
        config.allowUnfree = true;
      };
    })
  ];

  system.stateVersion = "25.05";
}