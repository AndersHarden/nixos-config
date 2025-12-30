{ pkgs, inputs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/hardware/intel.nix
    ../../modules/hardware/laptop.nix
    ../../modules/common/base.nix
    ../../modules/common/utils.nix
    ../../modules/profiles/desktop.nix
    ../../modules/profiles/services.nix
    ./hyprland.nix
    ../../modules/desktop/wine.nix
  ];

  # Ensure no ollama-related configuration remains
  # (Remove or comment out any ollama.* or services.ollama.* options if present)
 
  # Unika inställningar för denna dator
  networking.hostName = "laptop-intel";
  console.keyMap = "sv-latin1";

  nix.settings = {
    download-buffer-size = 536870912; # 512 MB
    max-jobs = "auto";
    cores = 0;
  };

  # LUKS och Bootloader
  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
  };

  # tialored blender for intel
  environment.systemPackages = with pkgs; [ # 'with pkgs;' gör att vi kan skriva 'unstable' istället för 'pkgs.unstable'
    unstable.blender
    calibre
  ];

  # ADB
  programs.adb.enable = true;

  # Flatpak
  services.flatpak.enable = true;
  
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