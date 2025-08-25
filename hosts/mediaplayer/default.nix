# Plats: ~/nixos-config/hosts/mediaplayer/default.nix
{ pkgs, inputs, ... }:

{
  imports = [
    # Hårdvara (måste genereras på denna dator)
    ./hardware-configuration.nix
    ../../modules/hardware/amd.nix

    # Gemensam bas
    ../../modules/common/base.nix
    # Notera: Vi exkluderar utils.nix och desktop.nix för en minimal installation

    # Profiler
    ../../modules/profiles/mediacenter.nix # Minimal profil
    ../../modules/profiles/services.nix   # För Syncthing/Tailscale
    ../../modules/profiles/server.nix     # För SSH

    # Aktivera Home Manager
    inputs.home-manager.nixosModules.default,

    # Importera din centrala användarkonfiguration
    # Överväg att skapa en separat, minimal anders-mediacenter.nix om du
    # vill ha ännu färre användarprogram på denna dator.
    ../../modules/home/anders.nix
  ];

  # Unika inställningar
  networking.hostName = "mediaplayer";
  console.keyMap = "sv-latin1";

  # Bootloader
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