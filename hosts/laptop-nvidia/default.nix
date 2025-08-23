{ pkgs, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/hardware/nvidia.nix
    ../../modules/hardware/laptop.nix # Extra laptop-inställningar
    ../../modules/common/base.nix
    ../../modules/common/utils.nix
    ../../modules/profiles/desktop.nix
  ];

    # ===============================================================
    # == 1. IMPORTERA HOME MANAGER-MODULEN                         ==
    # ===============================================================
    # Detta aktiverar Home Manager som en systemmodul så att vi kan
    # konfigurera den nedan.
    inputs.home-manager.nixosModules.default
  ];

  # Värdnamnet är redan korrekt för denna maskin
  networking.hostName = "laptop-nvidia";

  # ===============================================================
  # == HÅRDVARUSPECIFIKA INSTÄLLNINGAR FÖR NVIDIA-LAPTOPPEN      ==
  # ===============================================================

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

    # Ladda Intel-drivrutinen tidigt. Detta är ofta nödvändigt för
    # NVIDIA Optimus-laptops där Intel-GPU:n hanterar skärmen.
    initrd.kernelModules = [ "i915" ];

    kernelPackages = pkgs.linuxPackages_latest;
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
  };

  # ===============================================================
  # == FINGERAVTRYCKSLÄSAREN ÄR NU HELT BORTTAGEN                ==
  # ===============================================================

  # Swapfil
  swapDevices = [ { device = "/swapfile"; size = 8 * 1024; } ];

  # Unika paket för just denna laptop
  environment.systemPackages = with pkgs; [
    usbutils
    acpi
  ];

  # ===============================================================
  # == 2. TILLDELA EN HOME MANAGER-KONFIGURATION TILL ANVÄNDAREN  ==
  # ===============================================================
  # Här talar vi om för Home Manager att den ska hantera användaren "anders"
  # och att den ska använda konfigurationen från vår nya fil.
  home-manager.users.anders = {
    imports = [ ../../modules/home/anders.nix ];
  };

  # Overlay för att göra 'pkgs.unstable' tillgänglig
  nixpkgs.overlays = [
    (final: prev: {
      unstable = import inputs.nixpkgs-unstable {
        system = prev.system;
        config.allowUnfree = true;
      };
    })
  ]; # <-- HAKPARENTESEN FÖR LISTAN SLUTAR HÄR

  # Denna rad låg felaktigt INUTI overlays-listan
  system.stateVersion = "25.05";

} # <-- DENNA AVSLUTANDE MÅSVINGE SAKNADES