{
  config,
  pkgs,
  inputs,
  lib,
  hostKey,
  ...
}: let
  # Get the flake root path (known location)
  flakeRoot = "${config.home.homeDirectory}/.dotfiles/flake";
  # Host-specific output configs
  outputConfigs = {
    framework = ../niri/outputs-framework.kdl;
    desktop = ../niri/outputs-desktop.kdl;
  };

  # Get the host-specific output config file to symlink as host.kdl
  hostOutputConfig = outputConfigs.${hostKey} or null;

  # Function to auto-create symlinks for all files in a directory
  configSymlinks = configsPath: let
    inherit (config.lib.file) mkOutOfStoreSymlink;

    # Get the absolute path to the config directory in the flake
    configDir = "${flakeRoot}/home/nixos/desktop/dms/config";

    mkSymlink = name: {
      name = name;
      value = {
        source = mkOutOfStoreSymlink "${configDir}/${name}";
        force = true; # Force overwrite existing files to create symlinks
      };
    };
  in
    builtins.listToAttrs (map mkSymlink (builtins.attrNames (builtins.readDir configsPath)));
in {
  # Auto-symlink configuration files
  # This automatically creates symlinks for all files/directories in config folders
  # without needing to manually specify each file
  #
  # Benefits:
  # - Files are symlinked from git repo to ~/.config/
  # - Changes are instantly reflected (no rebuild needed)
  # - Just add new files to config folders and they're automatically symlinked
  # - All config files are version-controlled in your flake
  #
  # Based on: https://gist.github.com/mawkler/195def384fd3f73aeb9a965c82781483
  xdg.configFile = let
    # Auto-symlink all files from ./config/ to ~/.config/DankMaterialShell/
    dmsSymlinks = lib.mapAttrs' (name: value: {
      name = "DankMaterialShell/${name}";
      inherit value;
    }) (configSymlinks ./config);

    # Get absolute path for niri config directory in the flake
    niriDir = "${flakeRoot}/home/nixos/desktop/niri";

    # Auto-symlink all files from ../niri/ to ~/.config/niri/
    # Exclude config.kdl (symlinked separately) and outputs-*.kdl files (symlinked as host.kdl)
    niriFiles = builtins.readDir ../niri;
    niriFileNames = builtins.filter (
      name:
        name
        != "config.kdl"
        && ! (builtins.match "outputs-.*\\.kdl" name != null)
    ) (builtins.attrNames niriFiles);
    niriSymlinks = lib.listToAttrs (map (name: {
        name = "niri/${name}";
        value = {
          source = config.lib.file.mkOutOfStoreSymlink "${niriDir}/${name}";
          force = true; # Force overwrite existing files to create symlinks
        };
      })
      niriFileNames);
  in
    {
      # Symlink the base config.kdl (includes host.kdl via include statement)
      "niri/config.kdl" = {
        source = config.lib.file.mkOutOfStoreSymlink "${niriDir}/config.kdl";
        force = true;
      };

      # Symlink host.kdl to the appropriate outputs-<host>.kdl file
      # This allows the base config.kdl to include host-specific outputs
      "niri/host.kdl" =
        if hostOutputConfig != null
        then let
          # Determine the host-specific outputs file name
          outputsFileName =
            if hostKey == "framework"
            then "outputs-framework.kdl"
            else "outputs-desktop.kdl";
        in {
          source = config.lib.file.mkOutOfStoreSymlink "${niriDir}/${outputsFileName}";
          force = true;
        }
        else {
          # Fallback: create empty file if no host config found
          text = "// No host-specific output configuration\n";
          force = true;
        };
    }
    // dmsSymlinks
    // niriSymlinks;
}
