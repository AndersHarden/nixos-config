# modules/home/kitty.nix
{ config, pkgs, ... }:

{
  programs.kitty = {
    enable = true;

    settings = {
      font_family = "JetBrainsMono";
      font_size = 12;
      cursor_shape = "block";
      background_opacity = "0.65";
      background_blur = 64;
      window_border_width = 0;
      window_padding_width = 10;

      tab_bar_style = "separator";
      tab_powerline_style = "slanted";
      tab_bar_edge = "top";
      tab_title_max_length = 25;
      tab_title_template = " {title} ";
      tab_separator = " ";

      allow_remote_control = true;
      enabled_layouts = "splits";
      remember_window_size = false;
      initial_window_width = "75c";
      initial_window_height = "20c";
      confirm_os_window_close = 0;

      enable_audio_bell = false;
      "enabled_layouts tall:bias=50;full_size=1;mirrored=false" = "";
    };

    extraConfig = ''
      # Befintliga keymaps
      map ctrl+shift+t new_tab_with_cwd
      map ctrl+shift+n new_os_window_with_cwd

      # Automatisk inkludering av wal-färgfil
      #include ${config.home.homeDirectory}/.cache/wal/colors-kitty.conf
    '';
  };
}
