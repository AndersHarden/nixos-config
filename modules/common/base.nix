# ./modules/common/base.nix
{ pkgs, ... }:
{
  # Existing settings...
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;
  time.timeZone = "Europe/Stockholm";
  i18n.defaultLocale = "sv_SE.UTF-8";

  # Add binary cache configuration
  nix.settings = {
    substituters = [
      "https://cache.nixos.org/"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
  };

  # Använd den senaste kärnan för bättre hårdvarustöd
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # ===============================================================
  # == LÄGG TILL DETTA BLOCK FÖR NÄTVERKSHANTERING               ==
  # ===============================================================
  networking = {
    # Använd iwd för att hantera trådlösa nätverk
    wireless.iwd.enable = true;
    # Stäng av NetworkManager för att undvika konflikter
    networkmanager.enable = false;
  };

  services.upower.enable = true;

  # Ljud
  security.rtkit.enable = true;
  services.pipewire.enable = true;
  services.pipewire.alsa.enable = true;
  services.pipewire.pulse.enable = true;


  # Bluetooth
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  # Diskhantering
  services.gvfs.enable = true;
  services.udisks2.enable = true;
  security.polkit.enable = true;

  # Användare "anders"
  users.users.anders = {
    isNormalUser = true;
    description = "Anders Hardenborg";
    extraGroups = [ "networkmanager" "wheel" "kvm"];
  };

  # Grundläggande paket som alla behöver
  environment.systemPackages = with pkgs; [
    vim
    git
    htop
    fastfetch
    btop
    nautilus
    adwaita-icon-theme
    home-manager
    kdePackages.kate
    sysstat
    sushi
    loupe
    gnome-decoder
    ffmpegthumbnailer
    glance
    nautilus
    gnome-disk-utility
    gnome.gvfs
    udisks2
    ffmpeg
    mp4v2
    zlib
    stdenv.cc.cc.lib
  ];
}