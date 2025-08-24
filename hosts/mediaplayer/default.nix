# Plats: ~/nixos-config/hosts/mediaplayer/default.nix
{ pkgs, inputs, ... }:

{
  imports = [
    # Hårdvara (se till att denna fil är genererad på denna dator)
    ./hardware-configuration.nix
    ../../modules/hardware/amd.nix

    # Gemensam bas
    ../../modules/common/base.nix
    # Notera: Vi importerar INTE utils.nix eller desktop.nix

    # Profiler
    ../../modules/profiles/mediacenter.nix # Minimal profil
    ../../modules/profiles/server.nix      # Aktiverar SSH

    # Aktivera Home Manager
    inputs.home-manager.nixosModules.default,

    # Importera din centrala användarkonfiguration
    # Notera: Du kan skapa en separat, minimal anders-mediacenter.nix om du vill
    # ha ännu färre användarprogram på denna dator.
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

  # Overlay för instabila paket (kan behövas för vissa program)
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