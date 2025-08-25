# Plats: ~/nixos-config/hosts/laptop-nvidia/default.nix
{ pkgs, inputs, ... }:

{
  imports = [
    # Hårdvara (måste genereras på denna dator)
    ./hardware-configuration.nix
    ../../modules/hardware/nvidia.nix
    ../../modules/hardware/laptop.nix # Specifika laptop-inställningar

    # Gemensam bas
    ../../modules/common/base.nix
    ../../modules/common/utils.nix

    # Profiler
    ../../modules/profiles/desktop.nix
    ../../modules/profiles/services.nix # För Syncthing/Tailscale
    # Notera: server.nix (SSH) är exkluderad för säkerhet

    # Aktivera Home Manager
    inputs.home-manager.nixosModules.default,

    # Importera din centrala användarkonfiguration
    ../../modules/home/anders.nix
  ];

  # Unika inställningar
  networking.hostName = "laptop-nvidia";
  console.keyMap = "sv-latin1";

  # LUKS och Bootloader
  # VIKTIGT: Du måste ersätta UUID:t nedan med det korrekta för denna dator!
  # Kör `ls -l /dev/disk/by-uuid/` för att hitta det.
  boot = {
    initrd.luks.devices."root" = {
      device = "/dev/disk/by-uuid/DITT-UNIKA-UUID-FÖR-NVIDIA-LAPTOP-HÄR";
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