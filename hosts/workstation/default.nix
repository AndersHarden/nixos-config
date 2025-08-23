{ pkgs, inputs, ... }:

{
  imports = [
    # Hårdvara (se till att denna fil finns!)
    ./hardware-configuration.nix
    # Välj rätt GPU-modul för din workstation (t.ex. nvidia.nix)
    ../../modules/hardware/nvidia.nix

    # Gemensam bas
    ../../modules/common/base.nix
    ../../modules/common/utils.nix

    # Profiler
    ../../modules/profiles/desktop.nix

    # Home Manager
    inputs.home-manager.nixosModules.default
  ];

  # Unika inställningar för denna dator
  networking.hostName = "workstation";

  # Tangentbordslayout för konsol
  console.keyMap = "sv-latin1";

  # Bootloader (ingen LUKS här, antagligen)
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  # Home Manager-konfiguration för din användare
  home-manager.users.anders = {
    imports = [ ../../modules/home/anders.nix ];
  };

  # Overlay för instabila paket
  nixpkgs.overlays = [
    (final: prev: {
      unstable = import inputs.nixpkgs-unstable {
        system = prev.system;
        config.allowUnfree = true;
      };
    })
  ]; # <-- Kontrollera att denna hakparentes finns

  system.stateVersion = "25.05";

} # <-- DET ÄR TROLIGTVIS DENNA MÅSVINGE SOM SAKNAS