{ pkgs, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/hardware/amd.nix
    ../../modules/common/base.nix
    ../../modules/profiles/mediacenter.nix # Minimal profil
    ../../modules/profiles/server.nix     # För SSH
  ];

  # Unika inställningar
  networking.hostName = "mediaplayer";
  console.keyMap = "sv-latin1";

  # Bootloader
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };
  # tailored blender for AMD
  environment.systemPackages = with pkgs; [ # 'with pkgs;' gör att vi kan skriva 'unstable' istället för 'pkgs.unstable'
    (unstable.blender.override {
      rocmSupport = true;
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

  system.stateVersion = "25.11";
}