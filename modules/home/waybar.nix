{ config, pkgs, ... }:

let
  waybarConfig = builtins.toJSON {
    env = {
      PATH = "/home/anders/.local/bin:/home/anders/.nix-profile/bin:/run/current-system/sw/bin:/usr/bin:/bin";
    };
    layer = "top";
    modules-left = [ "hyprland/workspaces" ];
    modules-center = [ "clock" "idle_inhibitor" ];

    "hyprland/workspaces" = {
      format = "{icon}";
      format-icons = {
        "1" = "1";
        "2" = "2";
        "3" = "3";
        "4" = "4";
        "5" = "5";
        "6" = "6";
        "7" = "7";
        "8" = "8";
        "9" = "9";
        "10" = "10";
        urgent = "";
        active = "";
        default = "";
      };

      persistent_workspaces = {
        "1" = [ ];
        "2" = [ ];
        "3" = [ ];
        "4" = [ ];
        "5" = [ ];
        "6" = [ ];
        "7" = [ ];
        "8" = [ ];
        "9" = [ ];
        "10" = [ ];
      };
    };
    modules-right = [ "custom/set-random-wallpaper" "custom/resource-monitor" "bluetooth" "custom/network-vnstat" "tray" "pulseaudio" "custom/battery" ];

    idle_inhibitor = {
      format = "{icon}";
      format-icons = {
        activated = "󰅶";
        deactivated = "󰛊";
      };
    };

    "custom/set-random-wallpaper" = {
      format = " ";
      interval = 0;
      tooltip = "Set random wallpaper";
      "on-click" = "~/.local/bin/set-random-wallpaper";
    };

    "custom/resource-monitor" = {
      exec = "~/.local/bin/resource-monitor";
      format = "{text}";
      "return-type" = "json";
      interval = 5;
    };

    "custom/network-vnstat" = {
      exec = "~/.local/bin/waybar-network-vnstat";
      format = "{text}";
      "return-type" = "json";
      interval = 5;
      tooltip = true;
      "on-click" = "kitty --class=Impala -e impala";
    };

    clock = {
      interval = 60;
      tooltip = true;
      format = "{:%H.%M}";
      "tooltip-format" = "{:%Y-%m-%d}";
    };

    bluetooth = {
      format = "";
      "format-disabled" = "󰂲";
      "format-connected" = "";
      tooltip = true;
      "tooltip-format" = "Devices connected: {num_connections}";
      "on-click" = "kitty --class=bluetui -e bluetui";
    };

    pulseaudio = {
      format = "{icon}";
      "on-click" = "pavucontrol";
      "on-click-right" = "pamixer -t";
      "tooltip-format" = "Playing at {volume}%";
      "scroll-step" = 5;
      "format-muted" = "󰝟";
      "format-icons" = {
        default = [ "" "" "" ];
      };
    };

    "custom/battery" = {
      exec = "~/.local/bin/battery";
      format = "{text}";
      "return-type" = "json";
      interval = 30;
    };
  };
in
{
  programs.waybar = {
    enable = true;
  };

  xdg.configFile."waybar/config.jsonc" = {
    text = waybarConfig;
    force = true;
  };
  xdg.configFile."waybar/style.css".source = ./waybar/style.css;

  home.file.".local/bin/resource-monitor" = {
    source = ./waybar/scripts/resource-monitor.sh;
    executable = true;
  };
  home.file.".local/bin/battery" = {
    source = ./waybar/scripts/battery.sh;
    executable = true;
  };

  home.packages = with pkgs; [
    jq
    bluetui
    pavucontrol
  ];
}
