{
  description = "jadee | NixOS & Darwin Flake";

  inputs = {
    nixpkgs = {
      url = "github:NixOS/nixpkgs/";
    };

    nix-darwin = {
       url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware = {
      url = "github:NixOS/nixos-hardware/master";
    };

    nixpkgs-unstable = {
      url = "github:NixOS/nixpkgs/nixos-unstable";
    };

    home-manager = {
      url = "github:nix-community/home-manager/";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nur = {
      url = "github:nix-community/NUR";
    };

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nil = {
      url = "github:oxalica/nil";
    };

    cursor = {
      url = "github:TudorAndrei/cursor-nixos-flake";
    };



    nix-homebrew = {
      url = "github:zhaofengli-wip/nix-homebrew";
    };

    homebrew-bundle = {
      url = "github:homebrew/homebrew-bundle";
      flake = false;
    };

    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };

    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };

    nu-scripts = {
      url = "github:nushell/nu_scripts";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nixos-hardware,
      nixpkgs-unstable,
      home-manager,
      flake-parts,
      sops-nix,
      nur,
      zen-browser,
      nil,
      cursor,
      nix-darwin,
      nix-homebrew,
      homebrew-bundle,
      homebrew-core,
      homebrew-cask,
      nu-scripts,
    }@inputs:
    let
      lib = nixpkgs.lib;
      # Import host data
      hostData = import ./data/hosts/hosts.nix;
      linuxSystems = [ "x86_64-linux" "aarch64-linux" ];
      darwinSystems = [ "aarch64-darwin" "x86_64-darwin" ];
      forAllSystems = f: nixpkgs.lib.genAttrs (linuxSystems ++ darwinSystems) f;


      # Helper to get pkgs for a system
      getPkgs = system: import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
        };
        overlays = [
          nur.overlays.default
        ];
      };

      # Helper to get unstable pkgs for a system
      getPkgsUnstable = system: import nixpkgs-unstable {
        inherit system;
        config = {
          allowUnfree = true;
        };
        overlays = [
          nur.overlays.default
        ];
      };

      # Common specialArgs for all configurations
      commonSpecialArgs = inputs // { 
        inherit hostData;
        inherit inputs;
      };

      # Helper to create home-manager configuration for any host
      # Usage: mkHomeManagerModule { hostKey = "framework"; user = "jadee"; isDarwin = false; }
      mkHomeManagerModule = { hostKey, user, isDarwin ? false }:
        let
          host = hostData.hosts.${hostKey} or { };
          homeModules = if isDarwin then [ ./home/shared ./home/darwin ] else [ ./home/shared ./home/nixos ];
        in {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            backupFileExtension = "backup";
            users.${user} = { config, pkgs, inputs, hostData, user, hostKey, ... }: {
              imports = homeModules;
              home = {
                username = user;
                homeDirectory = hostData.hosts.${hostKey}.homeDirectory;
                stateVersion = hostData.hosts.${hostKey}.stateVersion;
              };
            };
            extraSpecialArgs = {
              inherit inputs hostData user hostKey;
              inherit (inputs) nu-scripts;
            };
          };
        };

      # Helper to create standalone home-manager configuration
      # Usage: mkHomeConfiguration { hostKey = "framework"; user = "jadee"; isDarwin = false; }
      mkHomeConfiguration = { hostKey, user, isDarwin ? false }:
        let
          host = hostData.hosts.${hostKey} or { };
          system = host.system or (if isDarwin then "aarch64-darwin" else "x86_64-linux");
          pkgs = getPkgs system;
          homeModules = if isDarwin then [ ./home/shared ./home/darwin ] else [ ./home/shared ./home/nixos ];
        in home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = homeModules ++ [
            {
              home = {
                username = user;
                homeDirectory = hostData.hosts.${hostKey}.homeDirectory;
                stateVersion = hostData.hosts.${hostKey}.stateVersion;
              };
            }
          ];
          extraSpecialArgs = {
            inherit inputs hostData user hostKey;
            inherit (inputs) nu-scripts;
            pkgs-unstable = getPkgsUnstable system;
            host = host;
          };
        };

    in
    {
      # Formatters for all systems
      formatter = lib.genAttrs (linuxSystems ++ darwinSystems) (system:
        (getPkgs system).nixfmt-rfc-style
      );

      # Dev shells with tooling (formatter, language servers)
      devShells = lib.genAttrs (linuxSystems ++ darwinSystems) (system:
        let
          pkgs = getPkgs system;
        in
        pkgs.mkShell {
          packages = [
            pkgs.nixfmt-rfc-style
            pkgs.nil
            pkgs.nixd
          ];
        }
      );

      # NixOS Configurations
      nixosConfigurations = {
        framework = let
          host = hostData.hosts.framework or { };
          system = host.system or "x86_64-linux";
          hostKey = "framework";
          user = host.username or "jadee";
        in lib.nixosSystem {
          inherit system;
          pkgs = getPkgs system;
          specialArgs = commonSpecialArgs // { 
            pkgs-unstable = getPkgsUnstable system;
            host = host;
            inherit hostKey user;
          };
          modules = [
            ./hosts/framework
            sops-nix.nixosModules.sops
            home-manager.nixosModules.home-manager
            (mkHomeManagerModule { inherit hostKey user; })
          ];
        };

        desktop = let
          host = hostData.hosts.desktop or { };
          system = host.system or "x86_64-linux";
          hostKey = "desktop";
          user = host.username or "jadee";
        in lib.nixosSystem {
          inherit system;
          pkgs = getPkgs system;
          specialArgs = commonSpecialArgs // { 
            pkgs-unstable = getPkgsUnstable system;
            host = host;
            inherit hostKey user;
          };
          modules = [
            ./hosts/desktop
            sops-nix.nixosModules.sops
            home-manager.nixosModules.home-manager
            (mkHomeManagerModule { inherit hostKey user; })
          ];
        };
      };

      # Standalone Home Manager Configurations
      # Allows using: home-manager switch --flake .#framework
      homeConfigurations = {
        framework = let
          host = hostData.hosts.framework or { };
          hostKey = "framework";
          user = host.username or "jadee";
        in mkHomeConfiguration { inherit hostKey user; };

        desktop = let
          host = hostData.hosts.desktop or { };
          hostKey = "desktop";
          user = host.username or "jadee";
        in mkHomeConfiguration { inherit hostKey user; };

        caya = let
          host = hostData.hosts.caya or { };
          hostKey = "caya";
          user = host.username or "jadee";
        in mkHomeConfiguration { inherit hostKey user; isDarwin = true; };
      };

      # Darwin Configurations
      darwinConfigurations = {
        caya = let
          host = hostData.hosts.caya or { };
          system = host.system or "aarch64-darwin";
          hostKey = "caya";
          user = host.username or "jadee";
        in nix-darwin.lib.darwinSystem {
          inherit system;
          specialArgs = commonSpecialArgs // {
            host = host;
            inherit hostKey user;
          };
          modules = [
            home-manager.darwinModules.home-manager
            (mkHomeManagerModule { inherit hostKey user; isDarwin = true; })
            nix-homebrew.darwinModules.nix-homebrew
            {
              nix-homebrew = {
                inherit user;
                enable = true;
                taps = {
                  "homebrew/homebrew-core" = inputs.homebrew-core;
                  "homebrew/homebrew-cask" = inputs.homebrew-cask;
                  "homebrew/homebrew-bundle" = inputs.homebrew-bundle;
                };
                mutableTaps = false;
                autoMigrate = true;
              };
            }
            ./hosts/caya
          ];
        };
      };
    };
}
