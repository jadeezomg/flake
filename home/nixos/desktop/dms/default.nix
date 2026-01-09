{
  config,
  pkgs,
  inputs,
  lib,
  hostKey,
  ...
}: let
  # Base niri config (shared across all hosts)
  baseConfig = ../niri/config.kdl;

  # Host-specific output configs
  outputConfigs = {
    framework = ../niri/outputs-framework.kdl;
    desktop = ../niri/outputs-desktop.kdl;
  };

  # Get the host-specific output config, or null if not found
  hostOutputConfig = outputConfigs.${hostKey} or null;

  # Combine base config with host-specific output config
  combinedConfig =
    if hostOutputConfig != null
    then
      pkgs.writeText "niri-config.kdl" ''
        ${builtins.readFile baseConfig}
        ${builtins.readFile hostOutputConfig}
      ''
    else baseConfig;

  # Function to auto-create symlinks for all files in a directory
  configSymlinks = configsPath: configsAbsolutePath: let
    inherit (lib.file) mkOutOfStoreSymlink;

    mkSymlink = name: {
      name = name;
      value.source = mkOutOfStoreSymlink "${configsAbsolutePath}/${name}";
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
    # Exclude the base config.kdl since we combine it with host-specific configs
    niriFiles = builtins.readDir ../niri;
    niriFileNames = builtins.filter (name: name != "config.kdl") (builtins.attrNames niriFiles);
    niriSymlinks = lib.listToAttrs (map (name: {
        name = "niri/${name}";
        value.source = lib.file.mkOutOfStoreSymlink "${toString (../niri)}/${name}";
      })
      niriFileNames);
  in
    {
      # Niri config.kdl is combined from base + host-specific configs
      "niri/config.kdl".source = combinedConfig;
    }
    // dmsSymlinks
    // niriSymlinks;
}
