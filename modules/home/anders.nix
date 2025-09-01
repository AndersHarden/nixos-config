----------------------------------------
#./modules/home/anders.nix
----------------------------------------
# Plats: ~/nixos-config/modules/home/anders.nix
{ config, pkgs, specialArgs, ... }: # <--- Korrekt: tar emot specialArgs

let
  # Extrahera hostConfig från specialArgs
  hostConfig = specialArgs.config; # <--- Korrekt: extraherar config
in
{
  # Enable home manager programs
  programs.home-manager.enable = true;
  home.stateVersion = "25.05";

  # Kitty
  imports = [
    ./waybar.nix
    # Skicka det extraherade hostConfig till hyprland.nix
    (./hyprland.nix { inherit config pkgs hostConfig; })
    ./kitty.nix
    ./pywal.nix
    ./hyprpaper.nix
    ./config-files.nix
    ./scripts.nix
  ];

  # PATH och session-variabler
  home.sessionVariables = {
    PATH = "${config.home.homeDirectory}/.local/bin:${pkgs.stdenv.cc.cc}/bin:${pkgs.coreutils}/bin:${pkgs.git}/bin:${pkgs.gcc}/bin:${pkgs.bash}/bin";
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