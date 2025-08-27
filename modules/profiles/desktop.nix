# Plats: modules/profiles/desktop.nix
{ ... }:
{
  imports = [
    # Den nya modulen som aktiverar SDDM och den grafiska miljön
    ../desktop/environment.nix
    ../desktop/plymouth.nix


    # Dina befintliga moduler för programvara
    ../desktop/hyprland.nix
    ../desktop/theme.nix 
    ../desktop/browsers.nix
    ../desktop/chat.nix
    ../desktop/fonts.nix
    ../desktop/media-creation.nix
    ../desktop/mediaplayer.nix
    ../desktop/slicer.nix
    ../desktop/python.nix
    ../desktop/nix-ld.nix
    ../desktop/packages.nix
#    ../desktop/theme.nix # <-- LÄGG TILL DENNA RAD
  ];
}
