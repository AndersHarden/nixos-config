----------------------------------------
#./modules/home/hyprland.nix
----------------------------------------
# Plats: modules/home/hyprland.nix
{ config, pkgs, hostName, ... }: # <--- ÄNDRA HÄR: Ta emot 'hostName' direkt

{
  # Se till att Hyprland är aktiverat i Home Manager också,
  # men utan att definiera några inställningar här.
  # Detta säkerställer att Home Manager vet att Hyprland används
  # och kan hantera t.ex. Waybar-integration korrekt.
  wayland.windowManager.hyprland.enable = true;

  # Skapa den slutgiltiga hyprland.conf i användarens hemkatalog
  # som inkluderar de systemgenererade filerna.
  xdg.configFile."hypr/hyprland.conf".text = ''
    # Denna fil hanteras av Home Manager.
    # Inkluderar system- och host-specifika Hyprland-konfigurationer.

    # Inkludera den generella bas-konfigurationen
    source = /etc/hypr/hyprland-base.conf

    # Inkludera den host-specifika konfigurationen
    source = /etc/hypr/hyprland-${hostName}.conf # <--- Använd hostName direkt

    # Eventuella ytterligare användarspecifika inställningar kan läggas till här
    # (men det är oftast bättre att hålla dem i de systemgenererade filerna för enkelhetens skull)
  '';
}