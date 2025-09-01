#./flake.nix
{
  description = "Min familj av NixOS-maskiner";

  inputs = {
    nixpkgs.url = "github.com/nixos/nixpkgs/release-25.05";
    nixpkgs-unstable.url = "github.com/nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, ... }@inputs: {
    nixosConfigurations = {
      # Intel laptop
      laptop-intel = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; }; # <--- Behåll denna
        modules = [
          ./hosts/laptop-intel
          ./modules/common/base.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            # KORRIGERING HÄR:
            # extraSpecialArgs tar emot config från den omgivande NixOS-modulen
            home-manager.extraSpecialArgs = { config, ... }: { # <--- Lägg till 'config' här
              hostName = config.networking.hostName;
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
            home-manager.extraSpecialArgs = { config, ... }: { # <--- Lägg till 'config' här
              hostName = config.networking.hostName;
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
            home-manager.extraSpecialArgs = { config, ... }: { # <--- Lägg till 'config' här
              hostName = config.networking.hostName;
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
            home-manager.extraSpecialArgs = { config, ... }: { # <--- Lägg till 'config' här
              hostName = config.networking.hostName;
              inherit inputs;
            };
            home-manager.users.anders = import ./modules/home/anders.nix;
          }
        ];
      };
    };
  };
}