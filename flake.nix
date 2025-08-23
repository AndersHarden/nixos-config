{
  description = "Min familj av NixOS-maskiner";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/release-25.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      # Detta är SUPERVIKTIGT. Det tvingar Home Manager att använda
      # exakt samma version av nixpkgs som ditt system, vilket förhindrar konflikter.
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, ... }@inputs: {

    nixConfig = {
      extra-substituters = [ "https://cache.nixos.org/" ];
      extra-trusted-public-keys = [ "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=" ];
    };
    nixosConfigurations = {
      # 1. Workstation (Stationär, NVIDIA)
      workstation = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [ ./hosts/workstation ]; # Pekar på mappen
      };

      # 2. Mediaspelare (Stationär, AMD)
      mediaplayer = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [ ./hosts/mediaplayer ];
      };

      # 3. Laptop-NVIDIA
      "laptop-nvidia" = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [ ./hosts/laptop-nvidia ];
      };

      # 4. Laptop-Intel
      "laptop-intel" = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [ ./hosts/laptop-intel ];
      };
    };
  };
}