# Plats: modules/home/kitty.nix
{ pkgs, ... }:

{
  programs.kitty = {
    enable = true;
    settings = {
      # Grundläggande utseende
      font_family = "JetBrainsMono";
      font_size = 12;
      cursor_shape = "block";
      background_opacity = "0.65";
      background_blur = 64;
      window_border_width = 0;
      window_padding_width = 10;

      # Flik-fält (Tab bar)
      tab_bar_style = "separator";
      tab_powerline_style = "slanted";
      tab_bar_edge = "top";
      tab_title_max_length = 25;
      tab_title_template = " {title} ";
      tab_separator = " ";

      # Fönsterhantering
      allow_remote_control = true; # 'yes' blir true
      enabled_layouts = "splits";
      remember_window_size = false; # 'no' blir false
      initial_window_width = "75c"; # Värden med enheter måste vara strängar
      initial_window_height = "20c";
      confirm_os_window_close = 0;

      # Ljud
      enable_audio_bell = false;

      # Specialinställningar
      # För inställningar med kolon (:) måste nyckeln vara inom citattecken
      "enabled_layouts tall:bias=50;full_size=1;mirrored=false" = "";
    };

    # Keybindings (kortkommandon) hanteras separat i 'extraConfig'
    # eftersom de inte passar in i 'settings'-strukturen.
    extraConfig = ''
      # map ctrl+shift+d launch --type=background --cwd=current sh -c "thunar \"$(pwd)\"";
      # close_on_child_death yes;
      map ctrl+shift+t new_tab_with_cwd
      map ctrl+shift+n new_os_window_with_cwd
      # map ctrl+shift+e launch --type=background --cwd=current sh -c "/usr/bin/neovide --no-vsync --no-idle";
    '';
  };
}