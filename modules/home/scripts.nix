# Plats: ~/nixos-config/modules/home/scripts.nix
{ config, pkgs, ... }:

{
  # --- Installera våra egna skript ---
  home.file.".local/bin/set-random-wallpaper" = {
    source = ./scripts/set-random-wallpaper.sh;
    executable = true;
  };

  home.file.".local/bin/waybar-network-vnstat" = {
    source = ./scripts/waybar-network-vnstat.sh;
    executable = true;
  };

  home.packages = with pkgs; [
    jq
    iproute2
    iw
  ];

  # --- Systemd-tjänst och timer för wallpaper ---
  systemd.user.services.set-random-wallpaper = {
    Unit = { Description = "Set random wallpaper"; };
    Service = {
      ExecStart = "${config.home.homeDirectory}/.local/bin/set-random-wallpaper";
    };
  };

  systemd.user.timers.set-random-wallpaper = {
    Unit = { Description = "Run set-random-wallpaper every 5 minutes"; };
    Timer = {
      OnBootSec = "30s";
      OnUnitActiveSec = "5m";
      Unit = "set-random-wallpaper.service";
    };
    Install = { WantedBy = [ "timers.target" ]; };
  };
}
