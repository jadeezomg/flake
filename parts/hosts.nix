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

  # One nixpkgs import per system (lib/pkgs.nix). Each host reads its three
  # package sets from here once and hands the SAME values to the system's
  # specialArgs and to Home Manager's extraSpecialArgs, so nixpkgs is never
  # instantiated twice for one host. `pkgsFor` is also published as a
  # flake-parts module arg for parts/packages.nix (perSystem `pkgs`).
  pkgsFuncs = import ../lib/pkgs.nix { inherit inputs; };
  inherit (pkgsFuncs) pkgsFor getPkgsWithConfig;

  # `pkgs`, `pkgs-stable`, `pkgs-small` for one host. Only a host with
  # `nixpkgsConfig` (framework: rocmSupport) gets a private main import;
  # the other two channels are always the shared ones.
  hostPkgs =
    host:
    let
      inherit (host) system;
    in
    {
      pkgs = getPkgsWithConfig system [ ] (host.nixpkgsConfig or { });
      pkgs-stable = pkgsFor.${system}.stable;
      pkgs-small = pkgsFor.${system}.small;
    };

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
      inputs,
      packageSets,
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
      # `packageSets` is the host's `hostPkgs` result — the same `pkgs`,
      # `pkgs-stable`, `pkgs-small` the system modules see.
      extraSpecialArgs = {
        inherit
          inputs
          host
          hostData
          hostKey
          isDarwin
          dotfilesLib
          ;
      }
      // packageSets;
      users = {
        ${user} = mkUserCfg;
      }
      // lib.listToAttrs (map (g: lib.nameValuePair g.username mkUserCfg) guestHmUsers);
    };

  mkHomeManagerModule =
    {
      hostKey,
      user,
      packageSets,
      isDarwin ? false,
    }:
    {
      home-manager = homeManagerConfig {
        inherit
          user
          hostKey
          isDarwin
          inputs
          packageSets
          ;
      };
    };

  mkHostOutputs =
    hostKey: host:
    let
      inherit (host) system;
      isDarwin = lib.elem system darwinSystems;
      user = host.username;
      inherit (host) hostname;
      # Computed once; shared by the system's specialArgs and Home Manager's
      # extraSpecialArgs below. `pkgs-stable` / `pkgs-small` stay available
      # as special args for occasional per-package pinning.
      packageSets = hostPkgs host;
      inherit (packageSets) pkgs;
      nixosConfig = lib.nixosSystem {
        system = null;
        inherit pkgs;
        # `pkgs` reaches NixOS modules through `nixosSystem { pkgs }` above,
        # not through specialArgs (that would shadow the module-system arg).
        specialArgs =
          commonSpecialArgs
          // (removeAttrs packageSets [ "pkgs" ])
          // {
            inherit
              host
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
          (mkHomeManagerModule { inherit hostKey user packageSets; })
        ];
      };
    in
    {
      nixosConfigurations = lib.optionalAttrs (!isDarwin) { ${hostname} = nixosConfig; };

      darwinConfigurations = lib.optionalAttrs isDarwin (
        let
          darwinConfig = nix-darwin.lib.darwinSystem {
            inherit system pkgs;
            specialArgs =
              commonSpecialArgs
              // packageSets
              // {
                inherit
                  host
                  hostKey
                  user
                  isDarwin
                  inputs
                  ;
              };
            modules = [
              sops-nix.darwinModules.sops
              home-manager.darwinModules.home-manager
              (mkHomeManagerModule {
                inherit hostKey user packageSets;
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
  # Shared with the other flake-parts modules (parts/packages.nix) so the
  # perSystem `pkgs` is the same import the hosts use.
  _module.args.pkgsFor = pkgsFor;

  flake = hostOutputs;
}
