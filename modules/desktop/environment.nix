# Plats: modules/desktop/environment.nix
{ pkgs, ... }:

{
  # Aktivera den grafiska miljön (XWayland-stöd etc.)
  services.xserver.enable = true;

  # Konfigurera tangentbordslayout för den grafiska miljön
  services.xserver.xkb = {
    layout = "se";
    variant = "";
  };

  # VM
  programs.virt-manager.enable = true;
  users.groups.libvirtd.members = ["anders"];
  virtualisation.libvirtd = {
    enable = true;
    qemu.runAsRoot = true;
    qemu.swtpm.enable = true;
  };
  virtualisation.spiceUSBRedirection.enable = true;

  systemd.tmpfiles.rules = [
    "L /run/libvirt/nix-ovmf/OVMF_CODE.fd - - - - edk2-x86_64-code.fd"
    "L /run/libvirt/nix-ovmf/OVMF_VARS.fd - - - - edk2-x86_64-secure-code.fd"
  ];

  # Konfigurera Display Manager (SDDM) med Wayland-stöd
  services.displayManager.sddm = {
    enable = true;
    autoNumlock = true;
    wayland.enable = true;
    # Detta tema måste finnas i environment.systemPackages någonstans
    # (vilket det gör i din base.nix eller hyprland.nix)
    theme = "sddm-sugar-dark";
    settings = {
      Autologin = {
        Session = "hyprland";
        User = "anders";
      };
    };
  };
}