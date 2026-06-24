{ pkgs, inputs, lib, pkgsUnstable, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/hardware/nvidia.nix
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
  boot.kernelPackages = pkgs.linuxPackages_6_12;

  # Overlay för instabila paket (pekar på central import från flake.nix)
  nixpkgs.overlays = [
    (final: prev: {
      unstable = pkgsUnstable;
    })
  ];

  environment.systemPackages = with pkgs; [
    pkgsUnstable.blender
    pkgsUnstable.opencode
    picard
  ];

  system.stateVersion = "26.05";
}
