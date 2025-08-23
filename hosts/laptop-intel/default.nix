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
    plymouth = {
      enable = true;
      theme = "loader_2";
      themePackages = with pkgs; [
        (adi1090x-plymouth-themes.override { selected_themes = [ "loader_2" ]; })
      ];
    };

    # VIKTIGT: Verifiera att denna LUKS-partition är korrekt för DENNA dator!
    # Kör `ls -l /dev/disk/by-uuid/` för att hitta rätt UUID.
    initrd.systemd.enable = true;
    initrd.luks.devices."root".device = "/dev/nvme0n1p5";
    initrd.luks.devices."root".preLVM = true;

    consoleLogLevel = 3;
    initrd.verbose = false;
    kernelParams = [
      "quiet" "splash" "boot.shell_on_fail" "udev.log_priority=3"
      "rd.systemd.show_status=auto" "plymouth.use-initrd=true"
    ];
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