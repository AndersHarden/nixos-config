{ pkgs, ... }:
{
  nixpkgs.overlays = [
    (final: prev: {
      tailscale = prev.tailscale.overrideAttrs (old: {
        doCheck = false; # Disable tests to avoid /proc/net/tcp errors
      });
    })
  ];
}