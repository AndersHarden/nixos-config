# Plats: ~/nixos-config/hosts/laptop-intel/default.nix
{ pkgs, inputs, ... }:
{
  imports = [
    # Hårdvara
    ./hardware-configuration.nix
    ../../modules/hardware/intel.nix

    # Gemensam bas
    ../../modules/common/base.nix
    ../../modules/common/utils.nix

    # Profiler
    ../../modules/profiles/desktop.nix
    ../../modules/profiles/server.nix

    # Aktivera Home Manager som en systemmodul
    inputs.home-manager.nixosModules.default,

    # Importera din användarkonfiguration som en vanlig systemmodul
    ../../modules/home/anders.nix
  ];

  # Unika inställningar för denna dator
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