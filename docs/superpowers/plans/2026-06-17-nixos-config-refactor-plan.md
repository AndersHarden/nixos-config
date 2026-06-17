# NixOS Config Refactor & 26.05 Update Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor flake.nix to eliminate HM boilerplate duplication, extract users.nix/packages.nix from base.nix, and update from NixOS 25.11 to 26.05.

**Architecture:** A `mkHost` helper function in flake.nix wraps `nixosSystem` + shared HM config. `base.nix` remains the hub but imports newly-extracted `users.nix` and `packages.nix`. Input branches are bumped to 26.05.

**Tech Stack:** NixOS, flakes, home-manager

---

### Task 1: Extract users.nix from base.nix

**Files:**
- Create: `modules/common/users.nix`
- Modify: `modules/common/base.nix`

- [ ] **Step 1: Create modules/common/users.nix**

```nix
{ ... }:

{
  users.users.anders = {
    isNormalUser = true;
    description = "Anders Hardenborg";
    extraGroups = [ "wheel" "kvm" ];
  };
}
```

- [ ] **Step 2: Add import to base.nix and remove inline user block**

In `modules/common/base.nix`, add `./users.nix` to the imports list, and remove lines 62-67:

```nix
  imports = [
    ./overlays.nix
    ./users.nix
  ];
```

Remove:
```
  # Användare "anders"
  users.users.anders = {
    isNormalUser = true;
    description = "Anders Hardenborg";
    extraGroups = [ "wheel" "kvm"];
  };
```

- [ ] **Step 3: Commit**

```bash
git add modules/common/users.nix modules/common/base.nix
git commit -m "refactor: extract users.nix from base.nix"
```

---

### Task 2: Extract packages.nix from base.nix

**Files:**
- Create: `modules/common/packages.nix`
- Modify: `modules/common/base.nix`

- [ ] **Step 1: Create modules/common/packages.nix**

```nix
{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    vim
    git
    htop
    fastfetch
    btop
    nautilus
    adwaita-icon-theme
    home-manager
    kdePackages.kate
    sysstat
    sushi
    loupe
    gnome-decoder
    ffmpegthumbnailer
    glance
    gnome-disk-utility
    gnome.gvfs
    udisks2
    ffmpeg
    mp4v2
    zlib
    stdenv.cc.cc.lib
  ];
}
```

- [ ] **Step 2: Update base.nix imports and remove inline package block**

Add `./packages.nix` to imports and remove lines 69-93 from base.nix:

```
  # Grundläggande paket som alla behöver
  environment.systemPackages = with pkgs; [
    vim
    git
    htop
    ...
  ];
```

- [ ] **Step 3: Commit**

```bash
git add modules/common/packages.nix modules/common/base.nix
git commit -m "refactor: extract packages.nix from base.nix"
```

---

### Task 3: Refactor flake.nix with mkHost helper

**Files:**
- Modify: `flake.nix`

- [ ] **Step 1: Rewrite flake.nix**

Replace the entire file content:

```nix
{
  description = "Min familj av NixOS-maskiner";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager/release-25.11";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, ... }@inputs: let
    unstablePkgs = import nixpkgs-unstable {
      system = "x86_64-linux";
      config.allowUnfree = true;
    };

    mkHost = hostName: extraModules: nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; pkgsUnstable = unstablePkgs; };
      modules = extraModules ++ [
        ./modules/common/base.nix
        home-manager.nixosModules.home-manager
        ({ config, ... }: {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.extraSpecialArgs = {
            inherit hostName inputs;
            systemEtc = config.environment.etc;
          };
          home-manager.users.anders = {
            imports = [ ./modules/home/anders.nix ];
          };
        })
      ];
    };
  in {
    nixosConfigurations = {
      laptop-intel = mkHost "laptop-intel" [ ./hosts/laptop-intel ];
      laptop-nvidia = mkHost "laptop-nvidia" [ ./hosts/laptop-nvidia ];
      workstation = mkHost "workstation" [ ./hosts/workstation ];
    };
  };
}
```

- [ ] **Step 2: Commit**

```bash
git add flake.nix
git commit -m "refactor: add mkHost helper to eliminate HM boilerplate"
```

---

### Task 4: Update inputs to NixOS 26.05

**Files:**
- Modify: `flake.nix`
- Modify: `hosts/laptop-intel/default.nix`
- Modify: `hosts/laptop-nvidia/default.nix`
- Modify: `hosts/workstation/default.nix`
- Auto-generated: `flake.lock`

- [ ] **Step 1: Update nixpkgs branch in flake.nix**

Change:
```nix
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
```
to:
```nix
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
```

- [ ] **Step 2: Update home-manager branch in flake.nix**

Change:
```nix
    home-manager.url = "github:nix-community/home-manager/release-25.11";
```
to:
```nix
    home-manager.url = "github:nix-community/home-manager/release-26.05";
```

- [ ] **Step 3: Update stateVersion in all hosts**

In each of `hosts/laptop-intel/default.nix`, `hosts/laptop-nvidia/default.nix`, `hosts/workstation/default.nix`:

Change:
```nix
  system.stateVersion = "25.11";
```
to:
```nix
  system.stateVersion = "26.05";
```

- [ ] **Step 4: Update flake.lock**

Run:
```bash
nix flake update
```

- [ ] **Step 5: Verify evaluation**

Run:
```bash
nix flake check
```
Expected: no errors (warnings are OK).

- [ ] **Step 6: Commit**

```bash
git add flake.nix flake.lock hosts/laptop-intel/default.nix hosts/laptop-nvidia/default.nix hosts/workstation/default.nix
git commit -m "feat: update to NixOS 26.05"
```

---

### Task 5: Final verification

- [ ] **Step 1: Run nix flake check**

```bash
nix flake check
```
Expected: all checks pass.

- [ ] **Step 2: Show final state**

```bash
git log --oneline -5
git diff --stat
```

**Expected:** 4-5 commits, clean diff, all hosts evaluate.
