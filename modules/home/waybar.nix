# Plats: ~/nixos-config/modules/home/waybar.nix
{ pkgs, ... }:

let
  scriptsDir = ".config/waybar/scripts";
in
{
  # Del 1: Konfigurera Waybar-programmet
  programs.waybar = {
    enable = true;
    # Skapa en huvud-CSS som importerar de dynamiska färgerna från Pywal
    # och sedan vår statiska layoutfil.
    style = ''
      @import "/home/anders/.cache/wal/colors-waybar.css";
      ${builtins.readFile ./waybar/style.css}
    '';
    settings = {
      mainBar = {
        "modules-left" = [ "hyprland/workspaces" ];
        "modules-center" = [ "clock" "idle_inhibitor" ];
        "modules-right" = [
          "tray"
          "custom/resourcemon"
          "custom/network-vnstat"
          "bluetooth"
          "custom/scratchpad-indicator"
          "pulseaudio"
          "custom/battery"
          "custom/power"
 #         "custom/theme-icon"
 #         "custom/theme-color"
        ];

        "custom/resourcemon" = {
          format = "{}";
          interval = 2;
          exec = "${scriptsDir}/resource-monitor.sh";
          "return-type" = "json";
          "on-click" = "${pkgs.kitty}/bin/kitty -e ${pkgs.btop}/bin/btop";
        };

        "custom/network-vnstat" = {
          exec = "waybar-network-vnstat";
          format = "{}";
          tooltip = true;
          "return-type" = "json";
          "on-click" = "${pkgs.kitty}/bin/kitty --class=Impala -e ${pkgs.impala}/bin/impala";
        };

        bluetooth = {
          format = "";
          "format-disabled" = "󰂲 ";
          "format-connected" = " ";
          "tooltip-format" = "Devices connected: {num_connections}";
          "on-click" = "${pkgs.kitty}/bin/kitty --class=Bluetui -e ${pkgs.bluetui}/bin/bluetui";
        };

        idle_inhibitor = {
          format = "{icon}";
          "format-icons" = {
            activated = "";
            deactivated = "";
          };
        };
      

        "custom/battery" = {
          format = "{}";
          "return-type" = "json";
          interval = 5;
          exec = "${scriptsDir}/battery.sh";
          "on-click-middle" = "ladda-fullt";
          tooltip = true;
        };

        tray = {
          "icon-size" = 15;
          spacing = 10;
        };

        clock = {
          "tooltip-format" = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
          "on-click" = "${pkgs.gnome-calendar}/bin/gnome-calendar";
        };

        pulseaudio = {
          format = "{volume}% {icon} ";
          "format-bluetooth" = "{volume}% {icon} {format_source}";
          "format-bluetooth-muted" = " {icon} {format_source}";
          "format-muted" = "0% {icon} ";
          "format-source" = "{volume}% ";
          "format-source-muted" = "";
          "format-icons" = {
            headphone = "";
            "hands-free" = "";
            headset = "";
            phone = "";
            portable = "";
            car = "";
            default = [ "" "" "" ];
          };
          "on-click" = "${pkgs.pavucontrol}/bin/pavucontrol";
        };

        "custom/power" = {
          format = " ";
          "on-click" = "~/.config/rofi/scripts/powermenu_t1";
        };

        "custom/scratchpad-indicator" = {
          "format-text" = "{}hi";
          "return-type" = "json";
          interval = 3;
          exec = "~/.local/bin/scratchpad-indicator 2> /dev/null";
          "exec-if" = "exit 0";
          "on-click" = "${pkgs.hyprland}/bin/hyprlandmsg 'scratchpad show'";
          "on-click-right" = "${pkgs.hyprland}/bin/hyprlandmsg 'move scratchpad'";
        };

        "custom/theme-icon" = {
          exec = "${pkgs.jq}/bin/jq -r '.icon' ~/.config/waybar/theme.json";
          interval = 1;
          tooltip = true;
        };

        "custom/theme-color" = {
          exec = "${pkgs.jq}/bin/jq -r '.color' ~/.config/waybar/theme.json";
          interval = 1;
          tooltip = true;
        };
      };
    };
  };
  programs.pywal = {
    enable = true;
    # Detta talar om för pywal att den ska generera en CSS-fil
    # från vår mall och placera den där Waybar förväntar sig den.
    templates = {
      "waybar/style.css" = builtins.readFile ./waybar/style.css.tmpl;
    };
  };
  # Del 2: Placera dina anpassade skript i hemkatalogen
  home.file = {
    # Placera dina anpassade skript i hemkatalogen
    "${scriptsDir}/battery.sh" = {
      source = ./waybar/scripts/battery.sh;
      executable = true;
    };
    "${scriptsDir}/resource-monitor.sh" = {
      source = ./waybar/scripts/resource-monitor.sh;
      executable = true;
    };

    # Skapa en tom fallback-fil för att säkerställa att Waybar alltid
    # kan starta, även innan 'wal' har körts.
    ".cache/wal/colors-waybar.css".text = "";
  };
}