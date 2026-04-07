{inputs, ...}: let
  lib = inputs.nixpkgs.lib;
  inherit (inputs) nixpkgs nix-darwin home-manager sops-nix determinate nix-homebrew lanzaboote;

  pkgsFuncs = import ../lib/pkgs.nix {inherit inputs;};
  inherit (pkgsFuncs) getPkgs getPkgsStable;

  # Data
  hostData =
    if builtins.pathExists ../data/hosts/hosts.nix
    then import ../data/hosts/hosts.nix
    else {hosts = {};};

  # Home-manager modules per platform
  darwinSystems = ["aarch64-darwin"];
  homeModules = isDarwin:
    [
      inputs.sops-nix.homeModules.sops
      inputs.stylix.homeModules.stylix
    ]
    ++ (
      if isDarwin
      then [../home/shared ../home/darwin]
      else [../home/shared ../home/nixos]
    );

  # Special args passed to all system modules
  commonSpecialArgs = inputs // {inherit hostData inputs;};

  # Home-manager embedded module configuration
  homeManagerConfig = {
    user,
    hostKey,
    isDarwin,
    inputs,
    ...
  }: let
    system =
      if isDarwin
      then "aarch64-darwin"
      else "x86_64-linux";
  in {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    overwriteBackup = true;
    extraSpecialArgs = {
      inherit inputs hostData user hostKey isDarwin;
      pkgs = getPkgs system [];
      pkgs-stable = getPkgsStable system;
    };
    users.${user} = {
      imports = homeModules isDarwin;
      home = {
        username = user;
        homeDirectory = hostData.hosts.${hostKey}.homeDirectory;
        stateVersion = hostData.hosts.${hostKey}.stateVersion;
      };
    };
  };

  # Wrap homeManagerConfig as a system module
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

  # Standalone home-manager configuration (for homeConfigurations output)
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
    pkgs = getPkgs system [];
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
        inherit inputs hostData user hostKey isDarwin;
        pkgs = getPkgs system [];
        host = host;
      };
    };

  # Build outputs per host
  mkHostOutputs = hostKey: host: let
    system = host.system or "x86_64-linux";
    isDarwin = lib.elem system darwinSystems;
    user = host.username or "jadee";
    hostname = host.hostname or hostKey;
    pkgs = getPkgs system [];
    nixosConfig = lib.nixosSystem {
      # Pass null so eval-config.nix does not set removed nixpkgs.system; we set nixpkgs.hostPlatform below.
      system = null;
      pkgs = pkgs;
      specialArgs =
        commonSpecialArgs
        // {
          pkgs-stable = getPkgsStable system;
          host = host;
          inherit hostKey user isDarwin inputs system;
        };
      modules = [
        inputs.nixpkgs.nixosModules.readOnlyPkgs
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
      {${hostKey} = nixosConfig;}
      // lib.optionalAttrs (hostname != hostKey) {${hostname} = nixosConfig;}
    );

    darwinConfigurations = lib.optionalAttrs isDarwin (let
      darwinConfig = nix-darwin.lib.darwinSystem {
        inherit system;
        pkgs = getPkgs system [];
        specialArgs =
          commonSpecialArgs
          // {
            pkgs = getPkgs system [];
            pkgs-stable = getPkgsStable system;
            host = host;
            inherit hostKey user isDarwin inputs;
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
              mutableTaps = true;
              autoMigrate = true;
            };
          }
          (./. + "/../hosts/${hostKey}")
        ];
      };
    in
      {${hostKey} = darwinConfig;}
      // lib.optionalAttrs (hostname != hostKey) {${hostname} = darwinConfig;});

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
