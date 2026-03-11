{ pkgs, inputs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/hardware/nvidia.nix
    ../../modules/common/base.nix
    ../../modules/common/utils.nix
    ../../modules/profiles/desktop.nix
    ../../modules/profiles/services.nix
    ../../modules/profiles/server.nix
    ../../modules/desktop/quickemu.nix
    ./hyprland.nix
  ];

  # Unika inställningar
  networking.hostName = "workstation";
  console.keyMap = "sv-latin1";
  networking.firewall.allowedTCPPorts = [ 8080 ];
  networking.firewall.enable = false;

  # Bootloader (utan LUKS, vilket är vanligt för en stationär dator)
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  services.openssh.settings = {
    x11Forwarding = true;
  };

  # Kernel 6.12 för bättre kompatibilitet med äldre NVIDIA-drivrutiner
  boot.kernelPackages = lib.mkForce pkgs.linuxPackages_6_12;

  # Tailored blender for nvidia workstation
  environment.systemPackages = with pkgs; [
    (unstable.blender.override {
        cudaSupport = true;
    })
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