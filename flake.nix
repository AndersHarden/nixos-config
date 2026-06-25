{
  description = "Min familj av NixOS-maskiner";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager/release-26.05";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, ... }@inputs: let
    mkHost = hostName: extraModules: let
      unstablePkgs = import nixpkgs-unstable {
        system = "x86_64-linux";
        config.allowUnfree = true;
        overlays = [
          (final: prev: {
            waybar = prev.waybar.overrideAttrs (old: {
              patches = (old.patches or [ ]) ++ [ ./patches/waybar-hyprland-055.patch ./patches/waybar-keyboard-mode.patch ];
            });
          })
        ];
      };
    in nixpkgs.lib.nixosSystem {
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
