{
  description = "Min familj av NixOS-maskiner";

  inputs = {
    nixpkgs.url = "github.com/nixos/nixpkgs/release-25.05";
    nixpkgs-unstable.url = "github.com/nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github.com/nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, ... }@inputs: {
    nixosConfigurations = {
      # Intel laptop
      laptop-intel = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; }; # <--- ÅTERSTÄLL TILL DETTA
        modules = [
          ./hosts/laptop-intel
          ./modules/common/base.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            # TA BORT DENNA DEL HELT OCH HÅLLET:
            # home-manager.extraSpecialArgs = {
            #   hostName = config.networking.hostName;
            # };
            home-manager.users.anders = import ./modules/home/anders.nix;
          }
        ];
      };

      # Nvidia laptop
      laptop-nvidia = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; }; # <--- ÅTERSTÄLL TILL DETTA
        modules = [
          ./hosts/laptop-nvidia
          ./modules/common/base.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            # TA BORT DENNA DEL HELT OCH HÅLLET:
            # home-manager.extraSpecialArgs = {
            #   hostName = config.networking.hostName;
            # };
            home-manager.users.anders = import ./modules/home/anders.nix;
          }
        ];
      };

      # Mediaspelare
      mediaplayer = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; }; # <--- ÅTERSTÄLL TILL DETTA
        modules = [
          ./hosts/mediaplayer
          ./modules/common/base.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            # TA BORT DENNA DEL HELT OCH HÅLLET:
            # home-manager.extraSpecialArgs = {
            #   hostName = config.networking.hostName;
            # };
            home-manager.users.anders = import ./modules/home/anders.nix;
          }
        ];
      };

      # Workstation
      workstation = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; }; # <--- ÅTERSTÄLL TILL DETTA
        modules = [
          ./hosts/workstation
          ./modules/common/base.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            # TA BORT DENNA DEL HELT OCH HÅLLET:
            # home-manager.extraSpecialArgs = {
            #   hostName = config.networking.hostName;
            # };
            home-manager.users.anders = import ./modules/home/anders.nix;
          }
        ];
      };
    };
  };
}