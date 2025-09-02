# ./flake.nix
{
  description = "Min familj av NixOS-maskiner";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager/release-25.05";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, ... }@inputs: {
    nixosConfigurations = {
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
              systemEtc = config.environment.etc; # Move systemEtc here
            };
            home-manager.users.anders = import ./modules/home/anders.nix;
          }
        ];
      };
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
              hostName = "laptop-nvidia";
              inherit inputs;
              systemEtc = config.environment.etc;
            };
            home-manager.users.anders = import ./modules/home/anders.nix;
          }
        ];
      };
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
              hostName = "mediaplayer";
              inherit inputs;
              systemEtc = config.environment.etc;
            };
            home-manager.users.anders = import ./modules/home/anders.nix;
          }
        ];
      };
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
              hostName = "workstation";
              inherit inputs;
              systemEtc = config.environment.etc;
            };
            home-manager.users.anders = import ./modules/home/anders.nix;
          }
        ];
      };
    };
  };
}