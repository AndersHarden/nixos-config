# Design: Delad Hyprland Lua-modul för alla hostar

Datum: 2026-08-11
Status: Godkänd

## Problem

`~/.config/hypr/hyprland.lua` genereras bara på `workstation` eftersom home-manager-hyprland-blocket
(endast med Lua) finns i `hosts/workstation/hyprland.nix`. Laptop-hostarna (`laptop-nvidia`, `laptop-intel`)
har ingen home-manager-hyprland-modul och kör därför på Hyprlands genererade STUB-konfig.

## Lösning

Skapa en delad NixOS-modul `modules/desktop/hyprland-home.nix` som tar `hyprlandHostConfig` som argument.

Modulen ska:
1. Importera `./hyprland-base.nix` (bas-konfig + `programs.hyprland.enable`)
2. Bygga `fullLuaConfig = hyprlandBaseConfig + hyprlandHostConfig`
3. Skapa `validateLuaConfig` (build-time `loadfile`-validering) och registrera via `system.extraDependencies`
4. Sätt upp `home-manager.users.anders.wayland.windowManager.hyprland`:
   - `enable = true`, `configType = "lua"`, `settings = { }`
   - `systemd.enable = true`, `systemd.variables = ["--all"]`
   - `extraConfig = fullLuaConfig`
5. Lägga till `home.activation.checkHyprlandConfig` (luac-validering efter `linkGeneration`)

## Ändrade filer

- **Ny:** `modules/desktop/hyprland-home.nix`
- `hosts/workstation/hyprland.nix`: ersätt home-manager-blocket + valideringen med import av delad modul
- `hosts/laptop-nvidia/hyprland.nix`: lägg till import av delad modul
- `hosts/laptop-intel/hyprland.nix`: lägg till import av delad modul

## Omtöckning (avgränsning)

- `environment.etc."hypr/hyprland-<host>.conf"` behålls oförändrad (legacy)
- Inga andra host-specifika ändringar
