#./modules/home/anders.nix
{ config, pkgs, ... }:
{
  # Enable home manager programs
  programs.home-manager.enable = true;
  home.stateVersion = "26.05";

  # Kitty
  imports = [
    ./waybar.nix
    ./rofi.nix
    ./kitty.nix
    ./pywal.nix
    ./config-files.nix
    ./scripts.nix
    ./hyprpaper.nix
  ];

  home.packages = with pkgs; [
      gcc  # Inkluderar libstdc++.so.6
      python3  # Säkerställer att Python 3 är tillgängligt
      python3Packages.numpy  # Lägg till numpy via Nix (valfritt, se nedan)
      nerd-fonts.jetbrains-mono
  ];

  # PATH och session-variabler
  home.sessionVariables = {
    PATH = "${config.home.homeDirectory}/.local/bin:${pkgs.stdenv.cc.cc}/bin:${pkgs.coreutils}/bin:${pkgs.git}/bin:${pkgs.gcc}/bin:${pkgs.bash}/bin";
    LD_LIBRARY_PATH = "${pkgs.gcc.cc.lib}/lib";
    # NVIDIA Wayland kräver GBM-backend
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    LIBVA_DRIVER_NAME = "nvidia";
    # GTK: använd Wayland- backend, fallback till X11
    GDK_BACKEND = "wayland,x11";
    # NVIDIA Wayland optimizations
    NVD_BACKEND = "direct";
    # Tvinga GTK att använda Cairo-mjukvarurendering (kringgå NVIDIA subsurface-bugg)
    GDK_DEBUG = "gl-disable";
  };

  # Exempel fontconfig (enkel, utan att skriva till xdg.configFile)
  home.file."${config.home.homeDirectory}/.config/fontconfig/conf.d/10-hm-fonts.conf".text = ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
    <fontconfig>
      <!-- Dina fontconfig-inställningar här -->
    </fontconfig>
  '';
}