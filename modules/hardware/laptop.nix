{ config, pkgs, ... }:

# Använd en let-in-block för att definiera sökvägen till TLP en gång.
let
  # Detta ger oss den exakta sökvägen till tlp-binären i Nix-store.
  tlpPath = "${pkgs.tlp}/bin/tlp";
in
{
  # 1. Skapa ett skript som heter "ladda-fullt"
  environment.systemPackages = with pkgs; [
    cudaPackages.cudatoolkit
    (writeShellScriptBin "ladda-fullt" ''
      #!${pkgs.runtimeShell}
      echo "Instruerar TLP att ladda batteriet till 100% för denna session..."
      # Använd den fullständiga sökvägen till sudo och tlp för säkerhet och pålitlighet
      ${pkgs.sudo}/bin/sudo ${tlpPath} fullcharge BAT0
      echo "Klart! Batteriet kommer nu att ladda fullt. TLP återgår till normala inställningar efteråt."
    '')
  ];

  # 2. Tillåt din användare att köra kommandot utan lösenord
  security.sudo.extraRules = [
    {
      # Byt ut 'dittanvändarnamn' mot ditt faktiska användarnamn
      users = [ "anders" ];
      # Kommandot som tillåts köras som root utan lösenord
      commands = [
        {
          command = "${tlpPath} fullcharge BAT0";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  # ... resten av din konfiguration, inklusive TLP-inställningarna ...
  services.tlp = {
    enable = true;
    settings = {
      START_CHARGE_THRESH_BAT0 = 75;
      STOP_CHARGE_THRESH_BAT0 = 80;
    };
  };

  services.power-profiles-daemon.enable = false; # Behåll denna för att undvika konflikter
}
