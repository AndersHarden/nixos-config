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

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
  };

  # Kernel 6.12 för bättre kompatibilitet med äldre NVIDIA-drivrutiner
  boot.kernelPackages = lib.mkForce pkgs.linuxPackages_6_12;

  # Tailored blender for nvidia workstation
  environment.systemPackages = with pkgs; [
    (unstable.blender.override {
        cudaSupport = true;
    })
    unstable.opencode
    picard
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
