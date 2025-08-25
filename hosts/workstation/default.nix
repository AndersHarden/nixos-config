# Plats: ~/nixos-config/hosts/workstation/default.nix
{ pkgs, inputs, ... }:

{
  imports = [
    # Hårdvara (måste genereras på denna dator)
    ./hardware-configuration.nix
    ../../modules/hardware/nvidia.nix

    # Gemensam bas
    ../../modules/common/base.nix
    ../../modules/common/utils.nix

    # Profiler
    ../../modules/profiles/desktop.nix
    ../../modules/profiles/services.nix # För Syncthing/Tailscale
    ../../modules/profiles/server.nix   # För SSH

    # Aktivera Home Manager som en systemmodul
    inputs.home-manager.nixosModules.default,

    # Importera din centrala användarkonfiguration
    ../../modules/home/anders.nix
  ];

  # Unika inställningar
  networking.hostName = "workstation";
  console.keyMap = "sv-latin1";

  # Bootloader (utan LUKS, vilket är vanligt för en stationär dator)
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