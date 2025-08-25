# Plats: modules/profiles/services.nix
{ ... }:
{
  imports = [
    ../services/syncthing.nix
    ../services/tailscale.nix
  ];
}