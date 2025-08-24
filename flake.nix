# Plats: ~/nixos-config/flake.nix
{
  description = "Min familj av NixOS-maskiner";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/release-25.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-24.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, ... }@inputs: {
    # Nix-konfiguration för cache (oförändrad)
    nixConfig = {
      extra-substituters = [ "https://cache.nixos.org/" ];
      extra-trusted-public-keys = [ "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=" ];
    };

    # System-konfigurationer (oförändrad, men kommer att läsa en renare default.nix)
    nixosConfigurations = {
      "laptop-intel" = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [ ./hosts/laptop-intel ];
      };
      # ... dina andra datorer ...
    };

    # ===============================================================
    # == NY SEKTION: Separata Home Manager-konfigurationer         ==
    # ===============================================================
    homeConfigurations = {
      # Vi skapar en unik konfiguration för din användare på denna dator
      "anders@laptop-intel" = home-manager.lib.homeManagerConfiguration {
        # Använd samma paket-set som systemet
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        # Skicka med inputs ifall någon modul behöver dem
        extraSpecialArgs = { inherit inputs; };
        # Detta är ingångspunkten för din användarkonfiguration
        modules = [ ./modules/home/anders.nix ];
      };
      # Du kan lägga till fler användare här, t.ex. "anders@workstation"
    };
  };
}