{ pkgs, inputs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/hardware/intel.nix
    ../../modules/common/base.nix
    ../../modules/common/utils.nix
    ../../modules/profiles/desktop.nix
    ../../modules/profiles/services.nix
    ../../modules/services/ollama.nix
    ../../modules/services/open-webui.nix
  ];
 
  # Unika inställningar för denna dator
  networking.hostName = "laptop-intel";
  console.keyMap = "sv-latin1";

  # LUKS och Bootloader
  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
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