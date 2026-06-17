# Plats: modules/desktop/hyprland-base.nix
{ config, pkgs, ... }:

let
  # Definiera den generella Hyprland-konfigurationen i Lua-format
  # för Hyprland 0.55+
  hyprlandBaseConfig = ''
    -- Denna fil hanteras av NixOS. Ändra inte manuellt.
    -- Generella Hyprland-inställningar

    local mainMod = "SUPER"

    hl.config({
        general = {
            gaps_in = 5,
            gaps_out = 15,
            border_size = 2,
            col = {
                active_border = "rgba(faffb4aa)",
                inactive_border = "rgba(595959aa)",
            },
            resize_on_border = false,
            allow_tearing = false,
            layout = "dwindle",
        },

        dwindle = {
            preserve_split = true,
        },

        misc = {
            force_default_wallpaper = -1,
            disable_hyprland_logo = true,
        },

        input = {
            kb_layout = "se",
            follow_mouse = 1,
            sensitivity = 0,
            touchpad = {
                natural_scroll = true,
            },
            numlock_by_default = true,
        },

        cursor = {
            inactive_timeout = 10,
            enable_hyprcursor = false,
        },

        decoration = {
            rounding = 10,
            active_opacity = 1.0,
            inactive_opacity = 1.0,
            shadow = {
                enabled = true,
                range = 4,
                render_power = 3,
                color = "rgba(1a1a1aee)",
            },
            blur = {
                enabled = true,
                size = 8,
                passes = 2,
                new_optimizations = true,
                vibrancy = 0.1696,
            },
        },

        animations = {
            enabled = true,
        },
    })

    hl.gesture({
        fingers = 3,
        direction = "horizontal",
        action = "workspace",
    })

    hl.device({
        name = "epic-mouse-v1",
        sensitivity = -0.5,
    })

    -- Curves
    hl.curve("easeOutQuint", { type = "bezier", points = { {0.23, 1}, {0.32, 1} } })
    hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1} } })
    hl.curve("linear", { type = "bezier", points = { {0, 0}, {1, 1} } })
    hl.curve("almostLinear", { type = "bezier", points = { {0.5, 0.5}, {0.75, 1.0} } })
    hl.curve("quick", { type = "bezier", points = { {0.15, 0}, {0.1, 1} } })

    -- Animations
    hl.animation({ leaf = "global", enabled = true, speed = 10, bezier = "default" })
    hl.animation({ leaf = "border", enabled = true, speed = 5.39, bezier = "easeOutQuint" })
    hl.animation({ leaf = "windows", enabled = true, speed = 4.79, bezier = "easeOutQuint" })
    hl.animation({ leaf = "windowsIn", enabled = true, speed = 4.1, bezier = "easeOutQuint", style = "popin 87%" })
    hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.49, bezier = "linear", style = "popin 87%" })
    hl.animation({ leaf = "fadeIn", enabled = true, speed = 1.73, bezier = "almostLinear" })
    hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.46, bezier = "almostLinear" })
    hl.animation({ leaf = "fade", enabled = true, speed = 3.03, bezier = "quick" })
    hl.animation({ leaf = "layers", enabled = true, speed = 3.81, bezier = "easeOutQuint" })
    hl.animation({ leaf = "layersIn", enabled = true, speed = 4, bezier = "easeOutQuint", style = "fade" })
    hl.animation({ leaf = "layersOut", enabled = true, speed = 1.5, bezier = "linear", style = "fade" })
    hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 1.79, bezier = "almostLinear" })
    hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
    hl.animation({ leaf = "workspaces", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
    hl.animation({ leaf = "workspacesIn", enabled = true, speed = 1.21, bezier = "almostLinear", style = "fade" })
    hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })

    -- KEYBINDINGS (generella, utan multimedia)
    hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd("kitty"))
    hl.bind(mainMod .. " + Q", hl.dsp.window.close())
    hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("firefox"))
    hl.bind(mainMod .. " + M", hl.dsp.exit())
    hl.bind(mainMod .. " + CTRL + Q", hl.dsp.exec_cmd("~/.config/rofi/scripts/powermenu_t1"))
    hl.bind(mainMod .. " + E", hl.dsp.exec_cmd("nautilus"))
    hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
    hl.bind(mainMod .. " + CTRL + F", hl.dsp.window.fullscreen())
    hl.bind(mainMod .. " + CTRL + RETURN", hl.dsp.exec_cmd("~/.config/rofi/scripts/launcher_t1"))
    hl.bind(mainMod .. " + P", hl.dsp.window.pseudo()) -- dwindle
    hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit")) -- dwindle

    -- Move focus
    hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }))
    hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
    hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }))
    hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }))

    -- Switch workspaces
    hl.bind(mainMod .. " + 1", hl.dsp.focus({ workspace = 1 }))
    hl.bind(mainMod .. " + 2", hl.dsp.focus({ workspace = 2 }))
    hl.bind(mainMod .. " + 3", hl.dsp.focus({ workspace = 3 }))
    hl.bind(mainMod .. " + 4", hl.dsp.focus({ workspace = 4 }))
    hl.bind(mainMod .. " + 5", hl.dsp.focus({ workspace = 5 }))
    hl.bind(mainMod .. " + 6", hl.dsp.focus({ workspace = 6 }))
    hl.bind(mainMod .. " + 7", hl.dsp.focus({ workspace = 7 }))
    hl.bind(mainMod .. " + 8", hl.dsp.focus({ workspace = 8 }))
    hl.bind(mainMod .. " + 9", hl.dsp.focus({ workspace = 9 }))
    hl.bind(mainMod .. " + 0", hl.dsp.focus({ workspace = 10 }))

    -- Move active window
    hl.bind(mainMod .. " + SHIFT + 1", hl.dsp.window.move({ workspace = 1 }))
    hl.bind(mainMod .. " + SHIFT + 2", hl.dsp.window.move({ workspace = 2 }))
    hl.bind(mainMod .. " + SHIFT + 3", hl.dsp.window.move({ workspace = 3 }))
    hl.bind(mainMod .. " + SHIFT + 4", hl.dsp.window.move({ workspace = 4 }))
    hl.bind(mainMod .. " + SHIFT + 5", hl.dsp.window.move({ workspace = 5 }))
    hl.bind(mainMod .. " + SHIFT + 6", hl.dsp.window.move({ workspace = 6 }))
    hl.bind(mainMod .. " + SHIFT + 7", hl.dsp.window.move({ workspace = 7 }))
    hl.bind(mainMod .. " + SHIFT + 8", hl.dsp.window.move({ workspace = 8 }))
    hl.bind(mainMod .. " + SHIFT + 9", hl.dsp.window.move({ workspace = 9 }))
    hl.bind(mainMod .. " + SHIFT + 0", hl.dsp.window.move({ workspace = 10 }))

    -- Special workspace
    hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"))
    hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

    -- Scroll workspaces
    hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
    hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

    -- Move/resize windows
    hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
    hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

    -- LAYER RULES
    hl.layer_rule({
        name = "blur-rofi",
        match = { namespace = "rofi" },
        blur = true,
    })
    hl.layer_rule({
        name = "blur-dunst",
        match = { namespace = "dunst" },
        blur = true,
    })
    hl.layer_rule({
        match = { namespace = "dunst" },
        blur = true,
        ignore_alpha = 0,
    })

    -- WINDOW RULES
    hl.window_rule({
        name = "fullscreen-waydroid",
        match = { class = "Waydroid", title = "Waydroid" },
        fullscreen = true,
    })
    hl.window_rule({
        name = "suppress-maximize",
        match = { class = ".*" },
        suppress_event = "maximize",
    })
    hl.window_rule({
        name = "xwayland-nofocus",
        match = {
            class = "^$",
            title = "^$",
            xwayland = true,
            float = true,
            fullscreen = false,
            pin = false,
        },
        no_focus = true,
    })
  '';
in
{
  # Aktivera system-stödet för Hyprland
  programs.hyprland.enable = true;

  # Skriv den generella konfigurationen till /etc/hypr/hyprland-base.conf
  environment.etc."hypr/hyprland-base.conf".text = hyprlandBaseConfig;
}
