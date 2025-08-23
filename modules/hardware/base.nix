{ pkgs, ... }:
{
  # Grundläggande systeminställningar
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;
  time.timeZone = "Europe/Stockholm";
  i18n.defaultLocale = "sv_SE.UTF-8";

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
  };

  # Grundläggande paket som alla behöver
  environment.systemPackages = with pkgs; [
    vim
    git
    htop
    fastfetch
    btop
  ];
}