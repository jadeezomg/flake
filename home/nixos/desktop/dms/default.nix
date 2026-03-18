{
  config,
  pkgs,
  inputs,
  lib,
  hostKey,
  ...
}: let
  flakeRoot = "${config.home.homeDirectory}/.dotfiles/flake";
  outputConfigs = {
    framework = ../niri/outputs-framework.kdl;
    desktop = ../niri/outputs-desktop.kdl;
  };

  hostOutputConfig = outputConfigs.${hostKey} or null;

  # Host-specific DMS settings files
  # Each host can have its own settings.json configuration
  settingsFiles = {
    framework = "settings-framework.json";
    desktop = "settings-desktop.json";
  };

  hostSettingsFile = settingsFiles.${hostKey} or "settings-desktop.json";

  configSymlinks = configsPath: let
    inherit (config.lib.file) mkOutOfStoreSymlink;

    configDir = "${flakeRoot}/home/nixos/desktop/dms/config";

    # Filter out settings.json and host-specific settings files
    allFiles = builtins.attrNames (builtins.readDir configsPath);
    filteredFiles =
      builtins.filter (
        name:
          name
          != "settings.json"
          && name != "settings-framework.json"
          && name != "settings-desktop.json"
      )
      allFiles;

    mkSymlink = name: {
      name = name;
      value = {
        source = mkOutOfStoreSymlink "${configDir}/${name}";
        force = true;
      };
    };
  in
    builtins.listToAttrs (map mkSymlink filteredFiles);
in {
  # Auto-symlink configuration files
  # This automatically creates symlinks for all files/directories in config folders
  # without needing to manually specify each file
  # Based on: https://gist.github.com/mawkler/195def384fd3f73aeb9a965c82781483
  xdg.configFile = let
    dmsSymlinks = lib.mapAttrs' (name: value: {
      name = "DankMaterialShell/${name}";
      inherit value;
    }) (configSymlinks ./config);

    niriDir = "${flakeRoot}/home/nixos/desktop/niri";
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
          force = true;
        };
      })
      niriFileNames);
  in
    {
      "niri/config.kdl" = {
        source = config.lib.file.mkOutOfStoreSymlink "${niriDir}/config.kdl";
        force = true;
      };

      "niri/host.kdl" =
        if hostOutputConfig != null
        then let
          outputsFileName =
            if hostKey == "framework"
            then "outputs-framework.kdl"
            else "outputs-desktop.kdl";
        in {
          source = config.lib.file.mkOutOfStoreSymlink "${niriDir}/${outputsFileName}";
          force = true;
        }
        else {
          text = "// No host-specific output configuration\n";
          force = true;
        };

      "DankMaterialShell/settings.json" = {
        source = config.lib.file.mkOutOfStoreSymlink "${flakeRoot}/home/nixos/desktop/dms/config/${hostSettingsFile}";
        force = true;
      };
    }
    // dmsSymlinks
    // niriSymlinks;
}
