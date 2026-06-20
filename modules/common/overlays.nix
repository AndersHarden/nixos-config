# Plats: modules/common/overlays.nix
{ pkgs, inputs, ... }:

let
  waybarHyprlandPatch = ../../patches/waybar-hyprland-055.patch;
  waybarKeyboardMode = ../../patches/waybar-keyboard-mode.patch;
in {
  nixpkgs.overlays = [
    (final: prev: {
      tailscale = prev.tailscale.overrideAttrs (old: {
        doCheck = false;
      });
    })

    # Patch waybar for Hyprland 0.55+ IPC + keyboard mode for tooltips
    (final: prev: {
      waybar = prev.waybar.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [ waybarHyprlandPatch waybarKeyboardMode ];
      });
    })
  ];
}
