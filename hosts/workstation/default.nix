{ pkgs, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/hardware/nvidia.nix
    ../../modules/common/base.nix
    ../../modules/common/utils.nix
    ../../modules/profiles/desktop.nix
    ../../modules/profiles/services.nix
    ../../modules/profiles/server.nix
    ./hyprland.nix
  ];

  # Unika inställningar
  networking.hostName = "workstation";
  console.keyMap = "sv-latin1";

  # Bootloader (utan LUKS, vilket är vanligt för en stationär dator)
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  # tialored blender for vnidia wirkstation
  environment.systemPackages = with pkgs; [ # 'with pkgs;' gör att vi kan skriva 'unstable' istället för 'pkgs.unstable'
    (unstable.blender.override {
        cudaSupport = true;
    })
  ];
    
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