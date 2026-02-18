{
  description = "Min familj av NixOS-maskiner";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager/release-25.11";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, ... }@inputs: let
    overlay-unstable = final: prev: {
      opencode = final.stdenv.mkDerivation {
        name = "opencode";
        src = final.fetchurl {
          url = "https://github.com/anomalyco/opencode/releases/download/v1.2.6/opencode-linux-x64.tar.gz";
          sha256 = "1299d49d1c9e8b07217d92cea14050650c0b5a81c2ac380d6ec0d1d26abbe61a";
        };
        unpackPhase = "true";
        installPhase = ''
          mkdir -p $out/bin
          tar -xzf $src
          mv opencode $out/bin/
          chmod +x $out/bin/opencode
        '';
        meta.mainProgram = "opencode";
      };
    };
    pkgsUnstable = import nixpkgs-unstable {
      system = "x86_64-linux";
      overlays = [ overlay-unstable ];
    };
  in {
    nixosConfigurations = {
      laptop-intel = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; pkgsUnstable = pkgsUnstable; };
        modules = [
          ./hosts/laptop-intel
          ./modules/common/base.nix
          home-manager.nixosModules.home-manager
          ({ config, pkgs, ... }: {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = {
              hostName = "laptop-intel";
              inherit inputs;
              systemEtc = config.environment.etc;
            };
            home-manager.users.anders = {
              imports = [ ./modules/home/anders.nix ];
            };
          })
        ];
      };
      laptop-nvidia = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; pkgsUnstable = pkgsUnstable; };
        modules = [
          ./hosts/laptop-nvidia
          ./modules/common/base.nix
          home-manager.nixosModules.home-manager
          ({ config, pkgs, ... }: {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = {
              hostName = "laptop-nvidia";
              inherit inputs;
              systemEtc = config.environment.etc;
            };
            home-manager.users.anders = {
              imports = [ ./modules/home/anders.nix ];
            };
          })
        ];
      };
      mediaplayer = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; pkgsUnstable = pkgsUnstable; };
        modules = [
          ./hosts/mediaplayer
          ./modules/common/base.nix
          home-manager.nixosModules.home-manager
          ({ config, pkgs, ... }: {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = {
              hostName = "mediaplayer";
              inherit inputs;
              systemEtc = config.environment.etc;
            };
            home-manager.users.anders = {
              imports = [ ./modules/home/anders.nix ];
            };
          })
        ];
      };
      workstation = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/workstation
          ./modules/common/base.nix
          home-manager.nixosModules.home-manager
          ({ config, pkgs, ... }: {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = {
              hostName = "workstation";
              inherit inputs;
              systemEtc = config.environment.etc;
            };
            home-manager.users.anders = {
              imports = [ ./modules/home/anders.nix ];
            };
          })
        ];
      };
    };
  };
}