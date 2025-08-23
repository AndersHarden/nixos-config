{ pkgs, inputs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/hardware/nvidia.nix
    ../../modules/common/base.nix
    ../../modules/common/utils.nix   # <-- LÄGG TILL DENNA RAD
    ../../modules/profiles/desktop.nix
  ];

    # ===============================================================
    # == 1. IMPORTERA HOME MANAGER-MODULEN                         ==
    # ===============================================================
    # Detta aktiverar Home Manager som en systemmodul så att vi kan
    # konfigurera den nedan.
    inputs.home-manager.nixosModules.default
  ];

  # Unika inställningar för denna dator
  networking.hostName = "workstation";
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