{
  description = "jadee | NixOS & Darwin Flake";

  inputs = {
    nixpkgs = {
      url = "github:NixOS/nixpkgs/nixos-25.11";
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
      url = "github:nix-community/home-manager/release-25.11";
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
      url = "github:0xc000022070/zen-browser-flake/463d3f091ad2b0ba2a4982f4181d22e452b2659d";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
      };
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
      linuxSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      darwinSystems = [
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      # Helper to get pkgs for a system
      getPkgs =
        system:
        import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
          };
          overlays = [
            nur.overlays.default
          ];
        };

      # Helper to get unstable pkgs for a system
      getPkgsUnstable =
        system:
        import nixpkgs-unstable {
          inherit system;
          config = {
            allowUnfree = true;
          };
          overlays = [
            nur.overlays.default
          ];
        };

      # Data paths
      dataPath = ./data;
      dataPathUsers = dataPath + "/users";
      dataPathUserExtras = dataPathUsers + "/extras";
      dataPathUserPreferences = dataPathUsers + "/preferences";
      dataPathHosts = dataPath + "/hosts/hosts.nix";

      # Import user data
      userData =
        if builtins.pathExists (dataPathUsers + "/users.nix") then
          import (dataPathUsers + "/users.nix")
        else
          { users = { }; };

      # Import user preferences (apps/profiles/etc.)
      userPreferences =
        if builtins.pathExists dataPathUserPreferences then import dataPathUserPreferences else { };

      # Import and pack all user extras data
      userExtras = {
        path = dataPathUserExtras;

        bookmarksData =
          if builtins.pathExists (dataPathUserExtras + "/bookmarks.nix") then
            import (dataPathUserExtras + "/bookmarks.nix")
          else
            { };

        profilesData =
          if builtins.pathExists (dataPathUserExtras + "/profiles.nix") then
            import (dataPathUserExtras + "/profiles.nix")
          else
            { };

        appsData =
          if builtins.pathExists (dataPathUserExtras + "/apps.nix") then
            import (dataPathUserExtras + "/apps.nix")
          else
            { };
      };

      # Import host data
      hostData = if builtins.pathExists dataPathHosts then import dataPathHosts else { hosts = { }; };

      # Common specialArgs for all configurations
      commonSpecialArgs = inputs // {
        inherit
          hostData
          userData
          userPreferences
          userExtras
          ;
        inherit inputs;
      };

      # Shared home module sets
      baseHomeModules =
        isDarwin:
        if isDarwin then
          [
            ./home/shared
            ./home/darwin
          ]
        else
          [
            ./home/shared
            ./home/nixos
          ];
      homeModules = isDarwin: [ inputs.sops-nix.homeManagerModules.sops ] ++ baseHomeModules isDarwin;

      # Helper to create home-manager configuration for any host
      # Usage: mkHomeManagerModule { hostKey = "framework"; user = "jadee"; isDarwin = false; }
      mkHomeManagerModule =
        {
          hostKey,
          user,
          isDarwin ? false,
        }:
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            backupFileExtension = "backup";
            users.${user} =
              {
                config,
                pkgs,
                inputs,
                hostData,
                user,
                hostKey,
                ...
              }:
              {
                imports = homeModules isDarwin;
                home = {
                  username = user;
                  homeDirectory = hostData.hosts.${hostKey}.homeDirectory;
                  stateVersion = hostData.hosts.${hostKey}.stateVersion;
                };
              };
            extraSpecialArgs = {
              inherit
                inputs
                hostData
                user
                hostKey
                userPreferences
                userExtras
                userData
                ;
              inherit (inputs) nu-scripts;
            };
          };
        };

      # Helper to create standalone home-manager configuration
      # Usage: mkHomeConfiguration { hostKey = "framework"; user = "jadee"; isDarwin = false; }
      mkHomeConfiguration =
        {
          hostKey,
          user,
          isDarwin ? false,
        }:
        let
          host = hostData.hosts.${hostKey} or { };
          system = host.system or (if isDarwin then "aarch64-darwin" else "x86_64-linux");
          pkgs = getPkgs system;
        in
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = homeModules isDarwin ++ [
            {
              home = {
                username = user;
                homeDirectory = hostData.hosts.${hostKey}.homeDirectory;
                stateVersion = hostData.hosts.${hostKey}.stateVersion;
              };
            }
          ];
          extraSpecialArgs = {
            inherit
              inputs
              hostData
              user
              hostKey
              userPreferences
              userExtras
              userData
              ;
            inherit (inputs) nu-scripts nu-plugin-tree;
            pkgs-unstable = getPkgsUnstable system;
            host = host;
          };
        };

      # Build outputs per host
      mkHostOutputs =
        hostKey: host:
        let
          system = host.system or "x86_64-linux";
          isDarwin = lib.elem system darwinSystems;
          user = host.username or "jadee";
        in
        {
          nixosConfigurations = lib.optionalAttrs (!isDarwin) {
            ${hostKey} = lib.nixosSystem {
              inherit system;
              pkgs = getPkgs system;
              specialArgs = commonSpecialArgs // {
                pkgs-unstable = getPkgsUnstable system;
                host = host;
                inherit hostKey user;
              };
              modules = [
                ./hosts/${hostKey}
                sops-nix.nixosModules.sops
                home-manager.nixosModules.home-manager
                (mkHomeManagerModule { inherit hostKey user; })
              ];
            };
          };

          darwinConfigurations = lib.optionalAttrs isDarwin {
            ${hostKey} = nix-darwin.lib.darwinSystem {
              inherit system;
              specialArgs = commonSpecialArgs // {
                host = host;
                inherit hostKey user;
              };
              modules = [
                sops-nix.darwinModules.sops
                home-manager.darwinModules.home-manager
                (mkHomeManagerModule {
                  inherit hostKey user;
                  isDarwin = true;
                })
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
                ./hosts/${hostKey}
              ];
            };
          };

          homeConfigurations = {
            ${hostKey} = mkHomeConfiguration {
              inherit hostKey user;
              isDarwin = isDarwin;
            };
          };
        };

      # Aggregate all per-host outputs
      hostOutputs = lib.foldl' lib.recursiveUpdate { } (
        lib.mapAttrsToList mkHostOutputs (hostData.hosts or { })
      );

    in
    {
      # Formatters for all systems
      formatter = lib.genAttrs (linuxSystems ++ darwinSystems) (
        system: (getPkgs system).nixfmt-rfc-style
      );

      # Dev shells with tooling (formatter, language servers)
      devShells = lib.genAttrs (linuxSystems ++ darwinSystems) (
        system:
        let
          pkgs = getPkgs system;
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.nixfmt-rfc-style
              pkgs.nil
              pkgs.nixd
            ];
          };
        }
      );
    }
    // hostOutputs;
}
