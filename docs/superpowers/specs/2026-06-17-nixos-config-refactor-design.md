# NixOS Config Refactor & 26.05 Update

## Goals

- Reduce duplication in flake.nix (home-manager block repeated 3x)
- Improve base.nix organization by extracting users and packages
- Keep host-specific configs unchanged
- Update from NixOS 25.11 to 26.05

## Changes

### 1. flake.nix — mkHost helper

- Create `mkHost` function that wraps `nixpkgs.lib.nixosSystem` + shared modules
- HM boilerplate (useGlobalPkgs, useUserPackages, extraSpecialArgs, users.anders) lives inside mkHost
- Single `pkgsUnstable` shared across all hosts
- Each host declaration becomes a one-liner:
  ```nix
  laptop-intel = mkHost "laptop-intel" [ ./hosts/laptop-intel ];
  ```

### 2. modules/common/ — Extract users.nix & packages.nix

- **modules/common/users.nix** — user "anders" definition (wheel/kvm groups, shell, etc.)
- **modules/common/packages.nix** — base packages list (vim, git, htop, etc.)
- **modules/common/base.nix** — retains all other config (nix settings, locale, timezone, networking, audio, bluetooth, pipewire, upower, etc.) plus imports users.nix and packages.nix

### 3. Host configs — Unchanged

No modifications to host-specific configs in `hosts/`.

### 4. Update inputs to NixOS 26.05

- `nixpkgs`: `nixos-25.11` → `nixos-26.05`
- `home-manager`: `release-25.11` → `release-26.05`

### 5. Environment

- `nix flake check` must pass after all changes
- All hosts must still build and evaluate without errors
