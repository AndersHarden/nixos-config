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
  virtualisation.libvirtd.enable = true;
  virtualisation.spiceUSBRedirection.enable = true;

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