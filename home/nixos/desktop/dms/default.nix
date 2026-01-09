{
  config,
  pkgs,
  inputs,
  lib,
  hostKey,
  ...
}: let
  # Host-specific output configs
  outputConfigs = {
    framework = ../niri/outputs-framework.kdl;
    desktop = ../niri/outputs-desktop.kdl;
  };

  # Get the host-specific output config file to symlink as host.kdl
  hostOutputConfig = outputConfigs.${hostKey} or null;

  # Function to auto-create symlinks for all files in a directory
  configSymlinks = configsPath: configsAbsolutePath: let
    inherit (config.lib.file) mkOutOfStoreSymlink;

    mkSymlink = name: {
      name = name;
      value = {
        source = mkOutOfStoreSymlink "${configsAbsolutePath}/${name}";
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
    }) (configSymlinks ./config "${toString (./. + "/config")}");

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
          source = config.lib.file.mkOutOfStoreSymlink "${toString (../niri)}/${name}";
          force = true; # Force overwrite existing files to create symlinks
        };
      })
      niriFileNames);
  in
    {
      # Symlink the base config.kdl (includes host.kdl via include statement)
      "niri/config.kdl" = {
        source = config.lib.file.mkOutOfStoreSymlink "${toString (../niri)}/config.kdl";
        force = true;
      };

      # Symlink host.kdl to the appropriate outputs-<host>.kdl file
      # This allows the base config.kdl to include host-specific outputs
      "niri/host.kdl" =
        if hostOutputConfig != null
        then {
          source = config.lib.file.mkOutOfStoreSymlink "${toString hostOutputConfig}";
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
