# ./flake.nix
{
  description = "Min familj av NixOS-maskiner";

  nixConfig = {
    extra-substituters = [
      "https://cache.nixos.org/"
    ];
    extra-trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager/release-25.05";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, ... }@inputs: {
    nixosConfigurations = {
      # Your existing configurations (laptop-intel, laptop-nvidia, etc.)
      laptop-intel = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/laptop-intel
          ./modules/common/base.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = {
              hostName = "laptop-intel";
              inherit inputs;
            };
            home-manager.users.anders = import ./modules/home/anders.nix;
          }
        ];
      };

      # Nvidia laptop
      laptop-nvidia = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/laptop-nvidia
          ./modules/common/base.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = {
              hostName = "laptop-nvidia"; # Direkt värde
              inherit inputs;
            };
            home-manager.users.anders = import ./modules/home/anders.nix;
          }
        ];
      };

      # Mediaspelare
      mediaplayer = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/mediaplayer
          ./modules/common/base.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = {
              hostName = "mediaplayer"; # Direkt värde
              inherit inputs;
            };
            home-manager.users.anders = import ./modules/home/anders.nix;
          }
        ];
      };

      # Workstation
      workstation = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/workstation
          ./modules/common/base.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = {
              hostName = "workstation"; # Direkt värde
              inherit inputs;
            };
            home-manager.users.anders = import ./modules/home/anders.nix;
          }
        ];
      };
    };
  };
}