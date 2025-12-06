{
  description = "jadee | NixOS & Darwin Flake";

  inputs = {
    nixpkgs = {
      url = "github:NixOS/nixpkgs/";
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

    darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
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
      darwin,
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

    in
    {
      # Formatters for all systems
      formatter = lib.genAttrs (linuxSystems ++ darwinSystems) (system:
        (getPkgs system).nixfmt-rfc-style
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
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                backupFileExtension = "backup";
                users.${user} = { config, pkgs, inputs, hostData, user, hostKey, ... }: {
                  imports = [
                    ./home/shared
                    ./home/nixos
                  ];

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
            }
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
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                backupFileExtension = "backup";
                users.${user} = { config, pkgs, inputs, hostData, user, hostKey, ... }: {
                  imports = [
                    ./home/shared
                    ./home/nixos
                  ];

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
            }
          ];
        };
      };

      # Darwin Configurations
      darwinConfigurations = {
        caya = let
          host = hostData.hosts.caya or { };
          system = host.system or "aarch64-darwin";
          hostKey = "caya";
          user = host.username or "jadee";
        in darwin.lib.darwinSystem {
          inherit system;
          specialArgs = commonSpecialArgs // {
            host = host;
            inherit hostKey user;
          };
          modules = [
            home-manager.darwinModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                backupFileExtension = "backup";
                users.${user} = { config, pkgs, inputs, hostData, user, hostKey, ... }: {
                  imports = [
                    ./home/shared
                    ./home/darwin
                  ];

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
            }
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
