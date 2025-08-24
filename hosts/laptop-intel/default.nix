# Plats: ~/nixos-config/hosts/laptop-intel/default.nix
{ pkgs, inputs, ... }:

{
  imports = [
    # Hårdvara
    ./hardware-configuration.nix
    ../../modules/hardware/intel.nix
    ../../modules/hardware/laptop.nix # Specifika laptop-inställningar

    # Gemensam bas
    ../../modules/common/base.nix
    ../../modules/common/utils.nix

    # Profiler
    ../../modules/profiles/desktop.nix
    # Notera: server.nix är borttagen för ökad säkerhet på en laptop

    # Aktivera Home Manager
    inputs.home-manager.nixosModules.default,

    # Importera din centrala användarkonfiguration
    ../../modules/home/anders.nix
  ];

  # Unika inställningar
  networking.hostName = "laptop-intel";
  console.keyMap = "sv-latin1";

  # LUKS och Bootloader
  boot = {
    initrd.luks.devices."root" = {
      device = "/dev/nvme0n1p5";
      preLVM = true;
    };
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
<<<<<<< HEAD

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
=======
>>>>>>> 41939e5 (feat(core): Finalize and stabilize modular configuration)
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