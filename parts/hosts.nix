{ inputs, ... }:
let
  lib = inputs.nixpkgs.lib;
  inherit (inputs)
    nix-darwin
    home-manager
    sops-nix
    determinate
    nix-homebrew
    lanzaboote
    ;

  pkgsFuncs = import ../lib/pkgs.nix { inherit inputs; };
  inherit (pkgsFuncs) getPkgsSmall getPkgsStable getPkgsWithConfig;

  hostData = import ../hosts/hosts.nix;

  # Named channel for cross-tree data/helpers (lib/default.nix) — passed to
  # every system and HM module so they never climb with ../../ imports.
  dotfilesLib = import ../lib;

  darwinSystems = [ "aarch64-darwin" ];

  # User config arrives via `home-manager.sharedModules` pushed by the
  # profiles (modules/profiles/*); only external input modules and the
  # flakeRoot option plumbing are imported unconditionally here.
  homeModules = [
    inputs.sops-nix.homeModules.sops
    inputs.stylix.homeModules.stylix
    inputs.vicinae.homeManagerModules.default
    ../lib/home/dotfiles.nix
  ];

  commonSpecialArgs = { inherit inputs hostData dotfilesLib; };

  homeManagerConfig =
    {
      user,
      hostKey,
      isDarwin,
      system,
      inputs,
      ...
    }:
    let
      host = hostData.hosts.${hostKey};
      guestHmUsers = builtins.filter (u: (u.manageHome or true)) (host.extraUsers or [ ]);
      mkUserCfg = {
        imports = homeModules;
        home.stateVersion = host.stateVersion;
      };
    in
    {
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
          dotfilesLib
          ;
        pkgs = getPkgsWithConfig system [ ] (host.nixpkgsConfig or { });
        pkgs-stable = getPkgsStable system;
        pkgs-small = getPkgsSmall system;
      };
      users = {
        ${user} = mkUserCfg;
      }
      // lib.listToAttrs (map (g: lib.nameValuePair g.username mkUserCfg) guestHmUsers);
    };

  mkHomeManagerModule =
    {
      hostKey,
      user,
      system,
      isDarwin ? false,
    }:
    {
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

  mkHostOutputs =
    hostKey: host:
    let
      system = host.system;
      isDarwin = lib.elem system darwinSystems;
      user = host.username;
      hostname = host.hostname;
      pkgs = getPkgsWithConfig system [ ] (host.nixpkgsConfig or { });
      nixosConfig = lib.nixosSystem {
        system = null;
        pkgs = pkgs;
        specialArgs = commonSpecialArgs // {
          pkgs-stable = getPkgsStable system;
          pkgs-small = getPkgsSmall system;
          host = host;
          inherit
            hostKey
            user
            isDarwin
            inputs
            system
            ;
        };
        # Only modules common to every Linux host belong here; single-host
        # modules (disko, hermes-agent, …) are imported by the
        # host's own `hosts/<name>/default.nix`.
        modules = [
          inputs.stylix.nixosModules.stylix
          inputs.dms.nixosModules.dank-material-shell
          inputs.dank-greeter.nixosModules.dank-greeter
          inputs.vicinae.nixosModules.default
          (./. + "/../hosts/${hostKey}")
          sops-nix.nixosModules.sops
          determinate.nixosModules.default
          lanzaboote.nixosModules.lanzaboote
          home-manager.nixosModules.home-manager
          (mkHomeManagerModule { inherit hostKey user system; })
        ];
      };
    in
    {
      nixosConfigurations = lib.optionalAttrs (!isDarwin) { ${hostname} = nixosConfig; };

      darwinConfigurations = lib.optionalAttrs isDarwin (
        let
          darwinConfig = nix-darwin.lib.darwinSystem {
            inherit system pkgs;
            specialArgs = commonSpecialArgs // {
              inherit
                pkgs
                host
                hostKey
                user
                isDarwin
                inputs
                ;
              pkgs-stable = getPkgsStable system;
              pkgs-small = getPkgsSmall system;
            };
            modules = [
              sops-nix.darwinModules.sops
              home-manager.darwinModules.home-manager
              (mkHomeManagerModule {
                inherit hostKey user system;
                isDarwin = true;
              })
              nix-homebrew.darwinModules.nix-homebrew
              # Writes /etc/nix/nix.custom.conf (substituters, trusted-users) and
              # forces nix.enable = false. See modules/darwin/nix.nix.
              determinate.darwinModules.default
              (./. + "/../hosts/${hostKey}")
            ];
          };
        in
        {
          ${hostname} = darwinConfig;
        }
      );
    };

  hostOutputs = lib.foldl' lib.recursiveUpdate { } (
    lib.mapAttrsToList mkHostOutputs (hostData.hosts or { })
  );
in
{
  flake = hostOutputs;
}
