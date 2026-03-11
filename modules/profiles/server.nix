# Plats: modules/profiles/server.nix
{ pkgs, ... }:

{
  # Utöka konfigurationen för användaren 'anders'
  users.users.anders = {
    # Lägg till SSH-nycklar för fjärråtkomst
    openssh.authorizedKeys.keys = [
      # laptop-intel
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINfBnuy7cFYKxy7J5LGISsdfAjlZ5JwjSnhYH5pMHKEE anders@workstation"
      # laptop-nvidia
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK+0CO+m+DwjDfKda3M8m71uk/gvVR91+sb3QIdQZE/j anders@workstation"
    ];
    # Lägg till extra grupper som behövs på stationära datorer
    extraGroups = [ "libvirtd" ];
    # Lägg till extra paket som behövs på stationära datorer
    packages = with pkgs; [
      tree
    ];
  };

  # Konfigurera SSH-åtkomst för root-användaren
  users.users.root.openssh.authorizedKeys.keys = [
    ''from="192.168.2.0/24" ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHUTAWSpaVlajPf3IxFcZV7SN4JhyH9sQfpoP9k3RiyS root@core-ssh root@workstation''
  ];

  # Aktivera SSH-servern
  services.openssh.enable = true;
}