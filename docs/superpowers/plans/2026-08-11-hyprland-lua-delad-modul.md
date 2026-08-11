# Delad Hyprland Lua-modul — Implementationsplan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Få alla tre hostar (workstation, laptop-nvidia, laptop-intel) att generera `~/.config/hypr/hyprland.lua` via en delad home-manager-modul istället för host-specifik duplicering.

**Architecture:** En ny NixOS-modul `modules/desktop/hyprland-home.nix` tar emot `hyprlandHostConfig` som argument och sätter upp (1) import av bas-konfig, (2) bygg-tids Lua-validering via `system.extraDependencies`, och (3) home-manager `wayland.windowManager.hyprland` med `configType = "lua"`. Varje host importerar modulen med `import ... { inherit hyprlandHostConfig; }` och behåller bara sin `environment.etc`-rad.

**Tech Stack:** Nix, NixOS module system, Home Manager, Lua, Hyprland 0.55+

## Global Constraints

- Alla ändringar får INTE bryta bygget av någon av de tre hostarna (`lua`-validering körs vid build)
- `hyprlandHostConfig`-strängen i varje host-fil ändras INTE (endast struktur runt omkring)
- `environment.etc."hypr/hyprland-<host>.conf"` behålls oförändrad
- Filer skrivs på svenska kommentarer, samma stil som befintlig kod
- Spec: `docs/superpowers/specs/2026-08-11-hyprland-lua-delad-modul-design.md`

---

### Task 1: Skapa delad modul och refaktorera workstation

**Files:**
- Create: `modules/desktop/hyprland-home.nix`
- Modify: `hosts/workstation/hyprland.nix`

**Interfaces:**
- Produces: `modules/desktop/hyprland-home.nix` — en funktion `{ hyprlandHostConfig }: ...` som returnerar en NixOS-modul. Konsumeras av alla tre host-filer som `import ../../modules/desktop/hyprland-home.nix { inherit hyprlandHostConfig; }`.

- [ ] **Step 1: Skapa `modules/desktop/hyprland-home.nix`**

```nix
# Plats: modules/desktop/hyprland-home.nix
# Delad NixOS-modul som sätter upp Home Manager Hyprland Lua-konfig
# Tar emot host-specifik hyprlandHostConfig och kombinerar med bas-konfig.
{ hyprlandHostConfig }:
{ pkgs, config, lib, ... }:

let
  hyprlandBaseConfig = import ./hyprland-base-lua.nix;

  fullLuaConfig = hyprlandBaseConfig + hyprlandHostConfig;

  # Build-time Lua syntax validation using loadfile (reliable parsing)
  hyprlandLuaConfigFile = builtins.toFile "hyprland.lua" fullLuaConfig;
  validateLuaConfig = pkgs.runCommandLocal "check-hyprland-lua-syntax" {
    nativeBuildInputs = [ pkgs.lua ];
  } ''
    cat > check.lua << 'EOF'
    local ok, err = loadfile("${hyprlandLuaConfigFile}")
    if not ok then
      io.stderr:write("--- Lua syntax error ---\n")
      io.stderr:write(err .. "\n")
      io.stderr:write("------------------------\n")
      os.exit(1)
    end
    EOF
    ${pkgs.lua}/bin/lua check.lua 2>&1 || {
      echo "----------------------------------------"
      echo "ERROR: Hyprland Lua config syntax check failed!"
      echo "----------------------------------------"
      cat ${hyprlandLuaConfigFile}
      echo "----------------------------------------"
      exit 1
    }
    echo "Hyprland Lua config syntax OK"
    touch $out
  '';
in
{
  imports = [
    ./hyprland-base.nix
  ];

  # Force Lua config validation to run at build time
  system.extraDependencies = [ validateLuaConfig ];

  # Skriv hyprland.lua via Home Manager direkt
  home-manager.users.anders = { pkgs, lib, ... }: {
    wayland.windowManager.hyprland = {
      enable = true;
      configType = "lua";
      settings = { };
      systemd = {
        enable = true;
        variables = [ "--all" ];
      };
      extraConfig = fullLuaConfig;
    };

    # Activation check: verifiera Lua-syntax vid home-manager switch
    home.activation.checkHyprlandConfig = lib.hm.dag.entryAfter ["linkGeneration"] ''
      CONF="$HOME/.config/hypr/hyprland.lua"
      if [ -f "$CONF" ]; then
        ${pkgs.lua}/bin/luac -p "$CONF" 2>/dev/null || {
          echo "ERROR: Hyprland Lua config validation failed at activation"
          echo "Check the generated file at $CONF"
          echo "----------------------------------------"
          cat "$CONF"
          echo "----------------------------------------"
          exit 1
        }
      fi
    '';
  };
}
```

- [ ] **Step 2: Refaktorera `hosts/workstation/hyprland.nix`**

Ersätt hela filens innehåll med (host-config-strängen behålls ordagrant):

```nix
# Plats: hosts/workstation/hyprland.nix
{ config, ... }:

let
  hyprlandHostConfig = ''
    -- Denna fil hanteras av NixOS. Ändra inte manuellt.
    -- Host-specifika Hyprland-inställningar för workstation

    -- MONITORS (Workstation)
    hl.monitor({
        output = "DP-1",
        mode = "3840x2160",
        position = "0x0",
        scale = 1.5,
    })
    hl.monitor({
        output = "HDMI-A-1",
        mode = "2560x1440",
        position = "2560x-600",
        scale = 1,
        transform = 1,
    })

    -- Workspace to monitor assignment
    hl.workspace_rule({ workspace = "1", monitor = "DP-1", default = true, persistent = true })
    hl.workspace_rule({ workspace = "2", monitor = "DP-1" })
    hl.workspace_rule({ workspace = "3", monitor = "DP-1" })

    -- AUTOSTART (Workstation)
    hl.on("hyprland.start", function()
        hl.exec_cmd("hyprctl keyword render:explicit_sync 0")
        hl.exec_cmd("waybar")
        hl.exec_cmd("hyprpaper")
        hl.exec_cmd("hypridle")
        hl.exec_cmd("set-random-wallpaper")
        hl.exec_cmd("trayscale --hide-window")
        hl.exec_cmd("hyprctl setcursor Adwaita 24")
    end)

    -- Multimedia keys (Workstation)
    hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true })
    hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true })
    hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
    hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
    hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl s 10%+"), { locked = true })
    hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl s 10%-"), { locked = true })
    hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
    hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
    hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
    hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
  '';
in
{
  imports = [
    (import ../../modules/desktop/hyprland-home.nix { inherit hyprlandHostConfig; })
  ];

  environment.etc."hypr/hyprland-${config.networking.hostName}.conf".text = hyprlandHostConfig;
}
```

- [ ] **Step 3: Verifiera att workstation bygger**

Run: `nixos-rebuild build --flake .#workstation`
Expected: bygget lyckas, och `"Hyprland Lua config syntax OK"` visas under bygget (validateLuaConfig körs). Om det tar för lång tid kan du istället köra: `nix build .#nixosConfigurations.workstation.config.system.build.toplevel --show-trace`

- [ ] **Step 4: Commit**

```bash
git add modules/desktop/hyprland-home.nix hosts/workstation/hyprland.nix
git commit -m "refactor: dela ut Hyprland Lua-home-modul, använd den i workstation"
```

---

### Task 2: Lägg till delad modul i laptop-nvidia

**Files:**
- Modify: `hosts/laptop-nvidia/hyprland.nix`

**Interfaces:**
- Consumes: `modules/desktop/hyprland-home.nix` från Task 1.

- [ ] **Step 1: Ändra `hosts/laptop-nvidia/hyprland.nix`**

Byt funktionsparametern till `{ config, ... }` och ersätt `imports`-blocket med import av den delade modulen. Host-config-strängen lämnas orörd:

```nix
# Plats: hosts/laptop-nvidia/hyprland.nix
{ config, ... }:

let
  hyprlandHostConfig = ''
    -- Denna fil hanteras av NixOS. Ändra inte manuellt.
    -- Host-specifika Hyprland-inställningar för laptop-nvidia

    -- MONITORS (Laptop nvidia)
    hl.monitor({
        output = "eDP-1",
        mode = "1920x1080",
        position = "0x0",
        scale = 1,
    })

    -- AUTOSTART (Laptop nvidia)
    hl.on("hyprland.start", function()
        hl.exec_cmd("waybar")
        hl.exec_cmd("hyprpaper")
        hl.exec_cmd("hypridle")
        hl.exec_cmd("set-random-wallpaper")
        hl.exec_cmd("trayscale --hide-window")
        -- hl.exec_cmd("/home/anders/.config/Scripts/battery-notify")
        hl.exec_cmd("hyprctl setcursor Adwaita 24")
    end)

    -- Multimedia keys (Laptop nvidia)
    hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true })
    hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true })
    hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
    hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
    hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl s 10%+"), { locked = true })
    hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl s 10%-"), { locked = true })
    hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
    hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
    hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
    hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
  '';
in
{
  imports = [
    (import ../../modules/desktop/hyprland-home.nix { inherit hyprlandHostConfig; })
  ];

  environment.etc."hypr/hyprland-${config.networking.hostName}.conf".text = hyprlandHostConfig;
}
```

- [ ] **Step 2: Verifiera att laptop-nvidia bygger**

Run: `nixos-rebuild build --flake .#laptop-nvidia`
Expected: bygget lyckas och Lua-valideringen körs. Denna maskin ÄR laptop-nvidia, så vid nästa `nixos-rebuild switch` skapas `~/.config/hypr/hyprland.lua`.

- [ ] **Step 3: Commit**

```bash
git add hosts/laptop-nvidia/hyprland.nix
git commit -m "feat: generera hyprland.lua på laptop-nvidia via delad modul"
```

---

### Task 3: Lägg till delad modul i laptop-intel

**Files:**
- Modify: `hosts/laptop-intel/hyprland.nix`

**Interfaces:**
- Consumes: `modules/desktop/hyprland-home.nix` från Task 1.

- [ ] **Step 1: Ändra `hosts/laptop-intel/hyprland.nix`**

Samma ändring som Task 2, fast för laptop-intel:

```nix
# Plats: hosts/laptop-intel/hyprland.nix
{ config, ... }:

let
  hyprlandHostConfig = ''
    -- Denna fil hanteras av NixOS. Ändra inte manuellt.
    -- Host-specifika Hyprland-inställningar för laptop-intel

    -- MONITORS (Laptop Intel)
    hl.monitor({
        output = "eDP-1",
        mode = "1920x1080",
        position = "0x0",
        scale = 1,
    })

    -- AUTOSTART (Laptop Intel)
    hl.on("hyprland.start", function()
        hl.exec_cmd("waybar")
        hl.exec_cmd("hyprpaper")
        hl.exec_cmd("hypridle")
        hl.exec_cmd("set-random-wallpaper")
        hl.exec_cmd("trayscale --hide-window")
        -- hl.exec_cmd("/home/anders/.config/Scripts/battery-notify")
        hl.exec_cmd("hyprctl setcursor Adwaita 24")
    end)

    -- Multimedia keys (Laptop Intel)
    hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true })
    hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true })
    hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
    hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
    hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl s 10%+"), { locked = true })
    hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl s 10%-"), { locked = true })
    hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
    hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
    hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
    hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
  '';
in
{
  imports = [
    (import ../../modules/desktop/hyprland-home.nix { inherit hyprlandHostConfig; })
  ];

  environment.etc."hypr/hyprland-${config.networking.hostName}.conf".text = hyprlandHostConfig;
}
```

- [ ] **Step 2: Verifiera att laptop-intel bygger**

Run: `nixos-rebuild build --flake .#laptop-intel`
Expected: bygget lyckas och Lua-valideringen körs.

- [ ] **Step 3: Commit**

```bash
git add hosts/laptop-intel/hyprland.nix
git commit -m "feat: generera hyprland.lua på laptop-intel via delad modul"
```

---

## Slutverifiering (end-to-end, körs manuellt av användaren)

På laptop-nvidia (denna maskin), när användaren nästa gång kör:
```bash
sudo nixos-rebuild switch --flake .#laptop-nvidia
```
ska `~/.config/hypr/hyprland.lua` skapas. Verifiera med:
```bash
ls -la ~/.config/hypr/hyprland.lua
```
Filen ska vara en home-manager-länk (symlink till `/nix/store/...-home-manager-files/...`), och ska INTE längre vara en STUB.
