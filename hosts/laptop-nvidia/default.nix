{ pkgs, inputs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/hardware/nvidia.nix
    ../../modules/hardware/intel.nix
    ../../modules/hardware/laptop.nix
    ../../modules/common/base.nix
    ../../modules/common/utils.nix
    ../../modules/profiles/desktop.nix
    ../../modules/profiles/services.nix
    ./hyprland.nix
  ];

  # Unika inställningar
  networking.hostName = "laptop-nvidia";
  console.keyMap = "sv-latin1";

  # LUKS och Bootloader
  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
  };

  # tialored blender for nvidia laptop
  environment.systemPackages = with pkgs; [ # 'with pkgs;' gör att vi kan skriva 'unstable' istället för 'pkgs.unstable'
    unstable.blender
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