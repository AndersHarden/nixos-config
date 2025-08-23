# Plats: modules/common/utils.nix
{ config, pkgs, ... }:
{
  # Tjänster
  services.vnstat.enable = true;

  # Paket med verktyg
  environment.systemPackages = with pkgs; [
    # Systemverktyg
    vscode
    blueberry
    lm_sensors
    bluetui
    vnstat
    bc
    jq
    upower
    gawk
    coreutils
    findutils
    libnotify

    # Nätverksverktyg
    iwd
    iproute2
    wirelesstools
    iw
    impala # <-- LÄGG TILL DEN HÄR RADEN
  ];
}