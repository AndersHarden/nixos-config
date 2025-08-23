{ pkgs, inputs, ... }:

{
  imports = [
    # Hårdvara
    ./hardware-configuration.nix
    ../../modules/hardware/intel.nix

    # Gemensam bas
    ../../modules/common/base.nix
    ../../modules/common/utils.nix

    # Profiler (Här kommer grafiken in!)
    ../../modules/profiles/desktop.nix

    # ===============================================================
    # == 1. IMPORTERA HOME MANAGER-MODULEN                         ==
    # ===============================================================
    # Detta aktiverar Home Manager som en systemmodul så att vi kan
    # konfigurera den nedan.
    inputs.home-manager.nixosModules.default
  ];

  # Unika inställningar för denna dator
  networking.hostName = "laptop-intel";

  # Tangentbordslayout för LUKS och konsol
  console.keyMap = "sv-latin1";

  # LUKS och Bootloader
  boot = {
    initrd.luks.devices."root" = {
      device = "/dev/nvme0-n1p5"; # Dubbelkolla att detta är rätt för denna dator
      preLVM = true;
    };
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
  };

  # ===============================================================
  # == 2. TILLDELA EN HOME MANAGER-KONFIGURATION TILL ANVÄNDAREN  ==
  # ===============================================================
  # Här talar vi om för Home Manager att den ska hantera användaren "anders"
  # och att den ska använda konfigurationen från vår nya fil.
  home-manager.users.anders = {
    imports = [ ../../modules/home/anders.nix ];
  };

  # Overlay för att göra 'pkgs.unstable' tillgänglig för Blender, Waybar, etc.
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