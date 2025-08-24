# Plats: modules/common/base.nix
{ pkgs, ... }:
{
  # Grundläggande systeminställningar
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;
  time.timeZone = "Europe/Stockholm";
  i18n.defaultLocale = "sv_SE.UTF-8";

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

  # Användare "anders"
  users.users.anders = {
    isNormalUser = true;
    description = "Anders Hardenborg";
    extraGroups = [ "networkmanager" "wheel" ];
    # Du kan lägga till din hashedPassword här om du vill
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
  ];
}