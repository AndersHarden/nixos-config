{ pkgs, inputs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/hardware/amd.nix
    ../../modules/common/base.nix
    ../../modules/profiles/mediacenter.nix # Denna ger bara mediaprogram
    ../../modules/profiles/server.nix 
  ];

    # ===============================================================
    # == 1. IMPORTERA HOME MANAGER-MODULEN                         ==
    # ===============================================================
    # Detta aktiverar Home Manager som en systemmodul så att vi kan
    # konfigurera den nedan.
    inputs.home-manager.nixosModules.default
  ];

  networking.hostName = "htpc";
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Definiera unstable-pkgs HÄR, en gång.
  nix.extraOptions = ''
  experimental-features = nix-command flakes;

  # ===============================================================
  # == 2. TILLDELA EN HOME MANAGER-KONFIGURATION TILL ANVÄNDAREN  ==
  # ===============================================================
  # Här talar vi om för Home Manager att den ska hantera användaren "anders"
  # och att den ska använda konfigurationen från vår nya fil.
  home-manager.users.anders = {
    imports = [ ../../modules/home/anders.nix ];
  };

  # Kopiera samma overlay-block som ovan
  nixpkgs.overlays = [ ... ];

  system.stateVersion = "25.05";
}