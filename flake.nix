{
  description = "Min familj av NixOS-maskiner";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    m4b-tool = {
      url = "github:sandreas/m4b-tool";
      inputs.nixpkgs.follows = "nixpkgs";  # Använd samma nixpkgs (25.05) för att undvika konflikter
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, m4b-tool, ... }@inputs: {
    nixosConfigurations = {
      laptop-intel = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
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
              home.packages = [
                m4b-tool.packages.${pkgs.system}.default  # Standard m4b-tool
                pkgs.ffmpeg  # Lägg till FFmpeg för m4b-tool
              ];
            };
            # Add overlay to disable tailscale tests
            nixpkgs.overlays = [
              (final: prev: {
                tailscale = prev.tailscale.overrideAttrs (old: {
                  doCheck = false; # Disable tests to avoid /proc/net/tcp errors
                });
              })
            ];
          })
        ];
      };
      laptop-nvidia = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
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
              home.packages = [
                m4b-tool.packages.${pkgs.system}.default  # Standard m4b-tool
                pkgs.ffmpeg  # Lägg till FFmpeg för m4b-tool
              ];
            };
            nixpkgs.overlays = [
              (final: prev: {
                tailscale = prev.tailscale.overrideAttrs (old: {
                  doCheck = false;
                });
              })
            ];
          })
        ];
      };
      mediaplayer = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
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
              home.packages = [
                m4b-tool.packages.${pkgs.system}.default  # Standard m4b-tool
                pkgs.ffmpeg  # Lägg till FFmpeg för m4b-tool
              ];
            };
            nixpkgs.overlays = [
              (final: prev: {
                tailscale = prev.tailscale.overrideAttrs (old: {
                  doCheck = false;
                });
              })
            ];
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
              home.packages = [
                m4b-tool.packages.${pkgs.system}.default  # Standard m4b-tool
                pkgs.ffmpeg  # Lägg till FFmpeg för m4b-tool
              ];
            };
            nixpkgs.overlays = [
              (final: prev: {
                tailscale = prev.tailscale.overrideAttrs (old: {
                  doCheck = false;
                });
              })
            ];
          })
        ];
      };
    };
  };
}