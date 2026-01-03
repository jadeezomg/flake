{inputs, ...}: let
  lib = inputs.nixpkgs.lib;
  inherit (inputs) nixpkgs nix-darwin home-manager sops-nix determinate nix-homebrew lanzaboote;

  # Load functions
  pkgsFuncs = import ./functions/pkgs.nix {inherit inputs;};
  inherit (pkgsFuncs) getPkgs getPkgsUnstable;

  dataFuncs = import ./functions/data.nix {dataPath = ../data;};
  inherit (dataFuncs) hostData userData userPreferences userExtras;

  modulesFuncs = import ./functions/modules.nix {
    inherit inputs hostData userData userPreferences userExtras;
  };
  inherit (modulesFuncs) commonSpecialArgs darwinSystems homeModules;

  hmModule = import ./modules/home-manager.nix {
    inherit inputs hostData userPreferences userExtras userData homeModules getPkgsUnstable;
  };
  inherit (hmModule) homeManagerConfig;

  # Helper to create home-manager configuration for any host
  mkHomeManagerModule = {
    hostKey,
    user,
    system,
    isDarwin ? false,
  }: {
    home-manager = homeManagerConfig {
      inherit user hostKey isDarwin inputs;
    };
  };

  # Helper to create standalone home-manager configuration
  mkHomeConfiguration = {
    hostKey,
    user,
    isDarwin ? false,
  }: let
    host = hostData.hosts.${hostKey} or {};
    system =
      host.system or (
        if isDarwin
        then "aarch64-darwin"
        else "x86_64-linux"
      );
    pkgs = getPkgs system;
  in
    home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules =
        homeModules isDarwin
        ++ [
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
          isDarwin
          ;
        pkgs-unstable = getPkgsUnstable system;
        host = host;
      };
    };

  # Build outputs per host
  mkHostOutputs = hostKey: host: let
    system = host.system or "x86_64-linux";
    isDarwin = lib.elem system darwinSystems;
    user = host.username or "jadee";
    hostname = host.hostname or hostKey;
    nixosConfig = lib.nixosSystem {
      inherit system;
      pkgs = getPkgs system;
      specialArgs =
        commonSpecialArgs
        // {
          pkgs-unstable = getPkgsUnstable system;
          host = host;
          inherit hostKey user isDarwin;
        };
      modules = [
        (./. + "/../hosts/${hostKey}")
        sops-nix.nixosModules.sops
        determinate.nixosModules.default
        lanzaboote.nixosModules.lanzaboote
        home-manager.nixosModules.home-manager
        (mkHomeManagerModule {inherit hostKey user system;})
      ];
    };
  in {
    nixosConfigurations = lib.optionalAttrs (!isDarwin) (
      {
        ${hostKey} = nixosConfig;
      }
      // lib.optionalAttrs (hostname != hostKey) {
        ${hostname} = nixosConfig;
      }
    );

    darwinConfigurations = lib.optionalAttrs isDarwin (let
      darwinConfig = nix-darwin.lib.darwinSystem {
        inherit system;
        pkgs = getPkgs system;
        specialArgs =
          commonSpecialArgs
          // {
            pkgs-unstable = getPkgsUnstable system;
            host = host;
            inherit hostKey user isDarwin;
          };
        modules = [
          sops-nix.darwinModules.sops
          home-manager.darwinModules.home-manager
          (mkHomeManagerModule {
            inherit hostKey user system;
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
          (./. + "/../hosts/${hostKey}")
        ];
      };
    in
      {
        ${hostKey} = darwinConfig;
      }
      // lib.optionalAttrs (hostname != hostKey) {
        ${hostname} = darwinConfig;
      });

    homeConfigurations = {
      ${hostKey} = mkHomeConfiguration {
        inherit hostKey user;
        isDarwin = isDarwin;
      };
    };
  };

  # Aggregate all per-host outputs
  hostOutputs = lib.foldl' lib.recursiveUpdate {} (
    lib.mapAttrsToList mkHostOutputs (hostData.hosts or {})
  );
in {
  flake = hostOutputs;
}
