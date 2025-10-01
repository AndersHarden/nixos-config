#./modules/home/anders.nix
{ config, pkgs, specialArgs, ... }: # <--- Ändrad signatur: tar emot specialArgs
let
  hostName = specialArgs.hostName; # Hämta hostName från specialArgs
in
{
  # Enable home manager programs
  programs.home-manager.enable = true;
  home.stateVersion = "25.05";

  # Kitty
  imports = [
    ./waybar.nix
    # Nu importerar vi hyprland.nix som en vanlig modul.
    # hostName är tillgängligt i hyprland.nix via dess egen specialArgs.
    ./hyprland.nix
    ./kitty.nix
    ./pywal.nix
    ./hyprpaper.nix
    ./config-files.nix
    ./scripts.nix
  ];

  home.packages = with pkgs; [
      gcc  # Inkluderar libstdc++.so.6
      python3  # Säkerställer att Python 3 är tillgängligt
      python3Packages.numpy  # Lägg till numpy via Nix (valfritt, se nedan)
  ];

  # PATH och session-variabler
  home.sessionVariables = {
    PATH = "${config.home.homeDirectory}/.local/bin:${pkgs.stdenv.cc.cc}/bin:${pkgs.coreutils}/bin:${pkgs.git}/bin:${pkgs.gcc}/bin:${pkgs.bash}/bin";
    LD_LIBRARY_PATH = "${pkgs.gcc.cc.lib}/lib";
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