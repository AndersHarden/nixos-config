# Plats: ~/nixos-config/modules/home/hyprland.nix
{ pkgs, ... }:

{
  # Detta är en ren Home Manager-modul.
  wayland.windowManager.hyprland = {
    enable = true;

    # 'settings' hanterar alla sektioner som är inneslutna i { ... }
    settings = {
      general = {
        gaps_in = 5;
        gaps_out = 15;
        border_size = 2;
        "col.active_border" = "rgba(faffb4aa)";
        "col.inactive_border" = "rgba(595959aa)";
        resize_on_border = false;
        allow_tearing = false;
        layout = "dwindle";
      };

      dwindle = {
        pseudotile = true;
        preserve_split = true;
      };

      master.new_status = "master";

      misc = {
        force_default_wallpaper = -1;
        disable_hyprland_logo = true;
      };

      input = {
        kb_layout = "se";
        follow_mouse = 1;
        sensitivity = 0;
        touchpad.natural_scroll = true;
        numlock_by_default = true;
      };

      gestures.workspace_swipe = true;

      device = {
        name = "epic-mouse-v1";
        sensitivity = -0.5;
      };

      cursor = {
        inactive_timeout = 10;
        enable_hyprcursor = false;
      };
    };

    # 'extraConfig' är för allt annat som inte passar i 'settings'.
    extraConfig = ''
      # Variabeldefinitioner måste komma först
      $mainMod = SUPER

      # DECORATION (placerad här för korrekt formatering)
      decoration {
          rounding = 10

          active_opacity = 1.0
          inactive_opacity = 1.0

          shadow {
              enabled = true
              range = 4
              render_power = 3
              color = rgba(1a1a1aee)
          }

          blur {
              enabled = true
              size = 8
              passes = 2
              new_optimizations = true
              vibrancy = 0.1696
          }
      }

      # MONITORS
      monitor= eDP-1, 1920x1080, 0x0, 1

      # MY PROGRAMS
      $terminal = ${pkgs.kitty}/bin/kitty
      $fileManager = ${pkgs.nautilus}/bin/nautilus
      $menu = ${pkgs.rofi-wayland}/bin/rofi
      $browser = ${pkgs.firefox}/bin/firefox

      # AUTOSTART
      exec-once = waybar
      exec-once = hyprpaper
      exec-once = hypridle
      exec-once = set-random-wallpaper
      exec-once = trayscale --hide-window
      # exec-once = /home/anders/.config/Scripts/battery-notify
      exec-once = hyprctl setcursor Adwaita 24

      # ANIMATIONS
      animations {
          enabled = yes
          bezier = easeOutQuint,0.23,1,0.32,1
          bezier = easeInOutCubic,0.65,0.05,0.36,1
          bezier = linear,0,0,1,1
          bezier = almostLinear,0.5,0.5,0.75,1.0
          bezier = quick,0.15,0,0.1,1
          animation = global, 1, 10, default
          animation = border, 1, 5.39, easeOutQuint
          animation = windows, 1, 4.79, easeOutQuint
          animation = windowsIn, 1, 4.1, easeOutQuint, popin 87%
          animation = windowsOut, 1, 1.49, linear, popin 87%
          animation = fadeIn, 1, 1.73, almostLinear
          animation = fadeOut, 1, 1.46, almostLinear
          animation = fade, 1, 3.03, quick
          animation = layers, 1, 3.81, easeOutQuint
          animation = layersIn, 1, 4, easeOutQuint, fade
          animation = layersOut, 1, 1.5, linear, fade
          animation = fadeLayersIn, 1, 1.79, almostLinear
          animation = fadeLayersOut, 1, 1.39, almostLinear
          animation = workspaces, 1, 1.94, almostLinear, fade
          animation = workspacesIn, 1, 1.21, almostLinear, fade
          animation = workspacesOut, 1, 1.94, almostLinear, fade
      }

      # KEYBINDINGS
      bind = $mainMod, RETURN, exec, $terminal
      bind = $mainMod, Q, killactive,
      bind = $mainMod, B, exec, $browser
      bind = $mainMod, M, exit,
      bind = $mainMod CTRL, Q, exec, ~/.config/rofi/scripts/powermenu_t1
      bind = $mainMod, E, exec, $fileManager
      bind = $mainMod, V, togglefloating,
      bind = $mainMod CTRL, F, fullscreen
      bind = $mainMod CTRL, RETURN, exec, ~/.config/rofi/scripts/launcher_t1
      bind = $mainMod, P, pseudo, # dwindle
      bind = $mainMod, J, togglesplit, # dwindle

      # Move focus
      bind = $mainMod, left, movefocus, l
      bind = $mainMod, right, movefocus, r
      bind = $mainMod, up, movefocus, u
      bind = $mainMod, down, movefocus, d

      # Switch workspaces
      bind = $mainMod, 1, workspace, 1
      bind = $mainMod, 2, workspace, 2
      bind = $mainMod, 3, workspace, 3
      bind = $mainMod, 4, workspace, 4
      bind = $mainMod, 5, workspace, 5
      bind = $mainMod, 6, workspace, 6
      bind = $mainMod, 7, workspace, 7
      bind = $mainMod, 8, workspace, 8
      bind = $mainMod, 9, workspace, 9
      bind = $mainMod, 0, workspace, 10

      # Move active window
      bind = $mainMod SHIFT, 1, movetoworkspace, 1
      bind = $mainMod SHIFT, 2, movetoworkspace, 2
      bind = $mainMod SHIFT, 3, movetoworkspace, 3
      bind = $mainMod SHIFT, 4, movetoworkspace, 4
      bind = $mainMod SHIFT, 5, movetoworkspace, 5
      bind = $mainMod SHIFT, 6, movetoworkspace, 6
      bind = $mainMod SHIFT, 7, movetoworkspace, 7
      bind = $mainMod SHIFT, 8, movetoworkspace, 8
      bind = $mainMod SHIFT, 9, movetoworkspace, 9
      bind = $mainMod SHIFT, 0, movetoworkspace, 10

      # Special workspace
      bind = $mainMod, S, togglespecialworkspace, magic
      bind = $mainMod SHIFT, S, movetoworkspace, special:magic

      # Scroll workspaces
      bind = $mainMod, mouse_down, workspace, e+1
      bind = $mainMod, mouse_up, workspace, e-1

      # Move/resize windows
      bindm = $mainMod, mouse:272, movewindow
      bindm = $mainMod, mouse:273, resizewindow

      # Multimedia keys
      bindel = ,XF86AudioRaiseVolume, exec, ${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
      bindel = ,XF86AudioLowerVolume, exec, ${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
      bindel = ,XF86AudioMute, exec, ${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
      bindel = ,XF86AudioMicMute, exec, ${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
      bindel = ,XF86MonBrightnessUp, exec, ${pkgs.brightnessctl}/bin/brightnessctl s 10%+
      bindel = ,XF86MonBrightnessDown, exec, ${pkgs.brightnessctl}/bin/brightnessctl s 10%-
      bindl = , XF86AudioNext, exec, ${pkgs.playerctl}/bin/playerctl next
      bindl = , XF86AudioPause, exec, ${pkgs.playerctl}/bin/playerctl play-pause
      bindl = , XF86AudioPlay, exec, ${pkgs.playerctl}/bin/playerctl play-pause
      bindl = , XF86AudioPrev, exec, ${pkgs.playerctl}/bin/playerctl previous

      # WINDOWS AND WORKSPACES
      layerrule = blur, rofi
      layerrule = blur, dunst
      layerrule = ignorezero, dunst
      windowrule = fullscreen, class:Waydroid, title:Waydroid
      windowrulev2 = suppressevent maximize, class:.*
      windowrulev2 = nofocus,class:^$,title:^$,xwayland:1,floating:1,fullscreen:0,pinned:0
    '';
  };
}