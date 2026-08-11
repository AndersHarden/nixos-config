# Plats: hosts/workstation/hyprland.nix
{ pkgs, config, lib, ... }:

let
  hyprlandBaseConfig = import ../../modules/desktop/hyprland-base-lua.nix;

  hyprlandHostConfig = ''
    -- Denna fil hanteras av NixOS. Ändra inte manuellt.
    -- Host-specifika Hyprland-inställningar för workstation

    -- MONITORS (Workstation)
    hl.monitor({
        output = "DP-1",
        mode = "3840x2160",
        position = "0x0",
        scale = 1.5,
    })
    hl.monitor({
        output = "HDMI-A-1",
        mode = "2560x1440",
        position = "2560x-600",
        scale = 1,
        transform = 1,
    })

    -- Workspace to monitor assignment
    hl.workspace_rule({ workspace = "1", monitor = "DP-1", default = true, persistent = true })
    hl.workspace_rule({ workspace = "2", monitor = "DP-1" })
    hl.workspace_rule({ workspace = "3", monitor = "DP-1" })

    -- AUTOSTART (Workstation)
    hl.on("hyprland.start", function()
        hl.exec_cmd("hyprctl keyword render:explicit_sync 0")
        hl.exec_cmd("waybar")
        hl.exec_cmd("hyprpaper")
        hl.exec_cmd("hypridle")
        hl.exec_cmd("set-random-wallpaper")
        hl.exec_cmd("trayscale --hide-window")
        hl.exec_cmd("hyprctl setcursor Adwaita 24")
    end)

    -- Multimedia keys (Workstation)
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

  fullLuaConfig = hyprlandBaseConfig + hyprlandHostConfig;

  # Build-time Lua syntax validation using loadfile (reliable parsing)
  hyprlandLuaConfigFile = builtins.toFile "hyprland.lua" fullLuaConfig;
  validateLuaConfig = pkgs.runCommandLocal "check-hyprland-lua-syntax" {
    nativeBuildInputs = [ pkgs.lua ];
  } ''
    cat > check.lua << 'EOF'
    local ok, err = loadfile("${hyprlandLuaConfigFile}")
    if not ok then
      io.stderr:write("--- Lua syntax error ---\n")
      io.stderr:write(err .. "\n")
      io.stderr:write("------------------------\n")
      os.exit(1)
    end
    EOF
    ${pkgs.lua}/bin/lua check.lua 2>&1 || {
      echo "----------------------------------------"
      echo "ERROR: Hyprland Lua config syntax check failed!"
      echo "----------------------------------------"
      cat ${hyprlandLuaConfigFile}
      echo "----------------------------------------"
      exit 1
    }
    echo "Hyprland Lua config syntax OK"
    touch $out
  '';
in
{
  imports = [
    ../../modules/desktop/hyprland-base.nix
  ];

  environment.etc."hypr/hyprland-${config.networking.hostName}.conf".text = hyprlandHostConfig;

  # Force Lua config validation to run at build time
  system.extraDependencies = [ validateLuaConfig ];

  # Skriv hyprland.lua via Home Manager direkt
  home-manager.users.anders = { pkgs, lib, ... }: {
    wayland.windowManager.hyprland = {
      enable = true;
      configType = "lua";
      settings = { };
      systemd = {
        enable = true;
        variables = [ "--all" ];
      };
      extraConfig = fullLuaConfig;
    };

    # Activation check: verifiera Lua-syntax vid home-manager switch
    home.activation.checkHyprlandConfig = lib.hm.dag.entryAfter ["linkGeneration"] ''
      CONF="$HOME/.config/hypr/hyprland.lua"
      if [ -f "$CONF" ]; then
        ${pkgs.lua}/bin/luac -p "$CONF" 2>/dev/null || {
          echo "ERROR: Hyprland Lua config validation failed at activation"
          echo "Check the generated file at $CONF"
          echo "----------------------------------------"
          cat "$CONF"
          echo "----------------------------------------"
          exit 1
        }
      fi
    '';
  };
}
