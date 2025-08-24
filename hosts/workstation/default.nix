# Plats: ~/nixos-config/hosts/workstation/default.nix
{ pkgs, inputs, ... }:

{
  imports = [
    # Hårdvara (se till att denna fil är genererad på denna dator)
    ./hardware-configuration.nix
    ../../modules/hardware/nvidia.nix

    # Gemensam bas
    ../../modules/common/base.nix
    ../../modules/common/utils.nix

    # Profiler
    ../../modules/profiles/desktop.nix
    ../../modules/profiles/server.nix   # Aktiverar SSH

    # Aktivera Home Manager
    inputs.home-manager.nixosModules.default,

    # Importera din centrala användarkonfiguration
    ../../modules/home/anders.nix
  ];

  # Unika inställningar
  networking.hostName = "workstation";
  console.keyMap = "sv-latin1";

  # Bootloader (antagligen ingen LUKS på en stationär)
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
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