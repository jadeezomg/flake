{inputs, ...}: let
  lib = inputs.nixpkgs.lib;
  inherit
    (inputs)
    nix-darwin
    home-manager
    sops-nix
    determinate
    nix-homebrew
    lanzaboote
    ;

  pkgsFuncs = import ../lib/pkgs.nix {inherit inputs;};
  inherit (pkgsFuncs) getPkgs getPkgsStable getPkgsWithConfig;

  hostData = import ../hosts/hosts.nix;

  darwinSystems = ["aarch64-darwin"];
  homeModules = isDarwin:
    [
      inputs.sops-nix.homeModules.sops
      inputs.stylix.homeModules.stylix
    ]
    ++ (
      if isDarwin
      then [
        ../home/shared
        ../home/darwin
      ]
      else [
        ../home/shared
        ../home/nixos
      ]
    );

  commonSpecialArgs = {inherit inputs hostData;};

  homeManagerConfig = {
    user,
    hostKey,
    isDarwin,
    system,
    inputs,
    ...
  }: let
    host = hostData.hosts.${hostKey};
    hmImports = homeModules isDarwin;
    guestHmUsers = builtins.filter (u: (u.manageHome or true)) (host.extraUsers or []);
    mkUserCfg = {
      imports = hmImports;
      home.stateVersion = host.stateVersion;
    };
  in {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    overwriteBackup = true;
    extraSpecialArgs = {
      inherit
        inputs
        host
        hostData
        hostKey
        isDarwin
        ;
      pkgs = getPkgsWithConfig system [] (host.nixpkgsConfig or {});
      pkgs-stable = getPkgsStable system;
    };
    users =
      {
        ${user} = mkUserCfg;
      }
      // lib.listToAttrs (map (g: lib.nameValuePair g.username mkUserCfg) guestHmUsers);
  };

  mkHomeManagerModule = {
    hostKey,
    user,
    system,
    isDarwin ? false,
  }: {
    home-manager = homeManagerConfig {
      inherit
        user
        hostKey
        isDarwin
        inputs
        system
        ;
    };
  };

  mkHostOutputs = hostKey: host: let
    system = host.system;
    isDarwin = lib.elem system darwinSystems;
    user = host.username;
    hostname = host.hostname;
    pkgs = getPkgsWithConfig system [] (host.nixpkgsConfig or {});
    nixosConfig = lib.nixosSystem {
      system = null;
      pkgs = pkgs;
      specialArgs =
        commonSpecialArgs
        // {
          pkgs-stable = getPkgsStable system;
          host = host;
          inherit
            hostKey
            user
            isDarwin
            inputs
            system
            ;
        };
      modules =
        [
          inputs.stylix.nixosModules.stylix
          inputs.dms.nixosModules.dank-material-shell
          inputs.dms.nixosModules.greeter
          inputs.disko.nixosModules.disko
          inputs.hermes-agent.nixosModules.default
        ]
        ++ lib.optional (
          (hostKey == "mini")
          && (!(host.miniBootstrap or false))
          && (host.miniLlmHosting or false)
        )
        inputs.vllm-xpu-nix.nixosModules.default
        ++ [
          (./. + "/../hosts/${hostKey}")
          sops-nix.nixosModules.sops
          determinate.nixosModules.default
          lanzaboote.nixosModules.lanzaboote
          home-manager.nixosModules.home-manager
          (mkHomeManagerModule {inherit hostKey user system;})
        ];
    };
  in {
    nixosConfigurations = lib.optionalAttrs (!isDarwin) {${hostname} = nixosConfig;};

    darwinConfigurations = lib.optionalAttrs isDarwin (
      let
        darwinConfig = nix-darwin.lib.darwinSystem {
          inherit system pkgs;
          specialArgs =
            commonSpecialArgs
            // {
              inherit
                pkgs
                host
                hostKey
                user
                isDarwin
                inputs
                ;
              pkgs-stable = getPkgsStable system;
            };
          modules = [
            sops-nix.darwinModules.sops
            home-manager.darwinModules.home-manager
            (mkHomeManagerModule {
              inherit hostKey user system;
              isDarwin = true;
            })
            nix-homebrew.darwinModules.nix-homebrew
            (./. + "/../hosts/${hostKey}")
          ];
        };
      in {
        ${hostname} = darwinConfig;
      }
    );
  };

  hostOutputs = lib.foldl' lib.recursiveUpdate {} (
    lib.mapAttrsToList mkHostOutputs (hostData.hosts or {})
  );
in {
  flake = hostOutputs;
}
