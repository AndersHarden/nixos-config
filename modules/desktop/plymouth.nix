# Plats: modules/desktop/plymouth.nix
{ pkgs, ... }:

{
  boot = {
    # Aktivera Plymouth
    plymouth = {
      enable = true;
      theme = "loader_2";
      themePackages = with pkgs; [
        (adi1090x-plymouth-themes.override {
          selected_themes = [ "loader_2" ];
        })
      ];
    };

    # Inställningar för "Silent Boot" som fungerar med Plymouth
    consoleLogLevel = 3;
    initrd.verbose = false;
    kernelParams = [
      "quiet"
      "splash"
      "boot.shell_on_fail"
      "udev.log_priority=3"
      "rd.systemd.show_status=auto"
      "plymouth.use-initrd=true"
    ];

    # Nödvändigt för att Plymouth ska kunna visa LUKS-prompten grafiskt
    initrd.systemd.enable = true;
  };
}