{ pkgs, inputs, lib, ... }:

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
 
  networking.hostName = "laptop-intel";
  console.keyMap = "sv-latin1";

  nix.settings = {
    download-buffer-size = 536870912;
    max-jobs = "auto";
    cores = 0;
  };

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
  };

  # tailored blender for intel + opencode
  environment.systemPackages = with pkgs; [
    unstable.blender
    calibre
    (pkgs.stdenv.mkDerivation {
      name = "opencode";
      src = pkgs.fetchurl {
        url = "https://github.com/anomalyco/opencode/releases/download/v1.2.6/opencode-linux-x64.tar.gz";
        sha256 = "1299d49d1c9e8b07217d92cea14050650c0b5a81c2ac380d6ec0d1d26abbe61a";
      };
      unpackPhase = "true";
      installPhase = ''
        mkdir -p $out/bin
        tar -xzf $src
        mv opencode $out/bin/
        chmod +x $out/bin/opencode
      '';
      meta.mainProgram = "opencode";
    })
  ];

  programs.adb.enable = true;

  services.flatpak.enable = true;
  
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