# Plats: hosts/laptop-nvidia/hyprland.nix
{ pkgs, config, ... }:

let
  hyprlandHostConfig = ''
    -- Denna fil hanteras av NixOS. Ändra inte manuellt.
    -- Host-specifika Hyprland-inställningar för laptop-nvidia

    -- MONITORS (Laptop nvidia)
    hl.monitor({
        output = "eDP-1",
        mode = "1920x1080",
        position = "0x0",
        scale = 1,
    })

    -- AUTOSTART (Laptop nvidia)
    hl.on("hyprland.start", function()
        hl.exec_cmd("waybar")
        hl.exec_cmd("hyprpaper")
        hl.exec_cmd("hypridle")
        hl.exec_cmd("set-random-wallpaper")
        hl.exec_cmd("trayscale --hide-window")
        -- hl.exec_cmd("/home/anders/.config/Scripts/battery-notify")
        hl.exec_cmd("hyprctl setcursor Adwaita 24")
    end)

    -- Multimedia keys (Laptop nvidia)
    hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true })
    hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true })
    hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
    hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
    hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl s 10%+"), { locked = true })
    hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl s 10%-"), { locked = true })
    hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
    hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
    hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
    hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
  '';
in
{
  imports = [
    ../../modules/desktop/hyprland-base.nix
  ];

  environment.etc."hypr/hyprland-${config.networking.hostName}.conf".text = hyprlandHostConfig;
}
