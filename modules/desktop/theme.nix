# Plats: modules/desktop/theme.nix
{ pkgs, ... }:
{
<<<<<<< HEAD
  # Aktivera NixOS-modulen för Pywal
  programs.pywal.enable = true;

  # Definiera Home Manager-inställningar för Pywal härifrån
  home-manager.users.anders = {
    # Notera den korrekta sökvägen: xresources.extraConfig
    # Pywal använder xresources för att lagra färger.
    # Vi kan också definiera mallar här.
    programs.pywal = {
      enable = true;
      templates = {
        # Sökvägen här är relativ till filen vi är i.
        "waybar/style.css" = builtins.readFile ../home/waybar/style.css.tmpl;
      };
    };
  };
=======
  # Detta säkerställer bara att NixOS känner till pywal.
  programs.pywal.enable = true;
>>>>>>> 41939e5 (feat(core): Finalize and stabilize modular configuration)
}