# Plats: hosts/laptop-intel/hyprland.nix
{ pkgs, config, ... }: # Lägg till 'config' här

let
  # Definiera den host-specifika Hyprland-konfigurationen som en sträng
  hyprlandHostConfig = pkgs.lib.strings.concatStringsSep "\n" [
    "# Denna fil hanteras av NixOS. Ändra inte manuellt."
    "# Host-specifika Hyprland-inställningar för laptop-intel"
    ""
    "# MONITORS (Laptop nvidia)"
    "monitor= eDP-1, 1920x1080, 0x0, 1"
    ""
    "# AUTOSTART (Laptop nvidia)"
    "exec-once = waybar"
    "exec-once = hyprpaper"
    "exec-once = hypridle"
    "exec-once = set-random-wallpaper"
    "exec-once = trayscale --hide-window"
    "# exec-once = /home/anders/.config/Scripts/battery-notify"
    "exec-once = hyprctl setcursor Adwaita 24"
    ""
    "# Multimedia keys (Laptop nvidia)"
    "bindel = ,XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
    "bindel = ,XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
    "bindel = ,XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
    "bindel = ,XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
    "bindel = ,XF86MonBrightnessUp, exec, brightnessctl s 10%+"
    "bindel = ,XF86MonBrightnessDown, exec, brightnessctl s 10%-"
    "bindl = , XF86AudioNext, exec, playerctl next"
    "bindl = , XF86AudioPause, exec, playerctl play-pause"
    "bindl = , XF86AudioPlay, exec, playerctl play-pause"
    "bindl = , XF86AudioPrev, exec, playerctl previous"
  ];
in
{
  imports = [
    ../../modules/desktop/hyprland-base.nix
  ];

  # Skriv den host-specifika konfigurationen till /etc/hypr/hyprland-laptop-intel.conf
  environment.etc."hypr/hyprland-${config.networking.hostName}.conf".text = hyprlandHostConfig;
}