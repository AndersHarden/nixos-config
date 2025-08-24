# Plats: ~/nixos-config/hosts/laptop-nvidia/default.nix
{ pkgs, inputs, ... }:

{
  imports = [
    # Hårdvara (se till att denna fil är genererad på denna dator)
    ./hardware-configuration.nix
    ../../modules/hardware/nvidia.nix
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
  networking.hostName = "laptop-nvidia";
  console.keyMap = "sv-latin1";

  # LUKS och Bootloader (anpassa efter denna dators partitioner)
  boot = {
    initrd.luks.devices."root" = {
      device = "/dev/disk/by-uuid/DITT-UNIKA-UUID-HÄR";
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