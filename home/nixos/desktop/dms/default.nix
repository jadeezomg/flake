{
  config,
  hostKey,
  ...
}: let
  inherit
    (import ../../../../lib/home/live-xdg-symlinks.nix {inherit config;})
    mkLiveSymlink
    xdgConfigDirSymlinks
    xdgConfigDirSymlinksPred
    ;

  flakeRoot = config.dotfiles.flakeRoot;
  dmsConfigDir = "${flakeRoot}/home/nixos/desktop/dms/config";
  niriDir = "${flakeRoot}/home/nixos/desktop/niri";

  settingsFiles = {
    framework = "settings-framework.json";
    desktop = "settings-desktop.json";
  };
  hostSettingsFile = settingsFiles.${hostKey} or "settings-desktop.json";
  settingsBasenames = builtins.attrValues settingsFiles;

  outputFiles = {
    framework = "outputs-framework.kdl";
    desktop = "outputs-desktop.kdl";
  };
  hostOutputFile = outputFiles.${hostKey} or null;

  niriPredicate = name:
    name != "config.kdl" && builtins.match "outputs-.*\\.kdl" name == null;
in {
  # Auto-symlink configuration files from the flake checkout (live paths).
  # Based on: https://gist.github.com/mawkler/195def384fd3f73aeb9a965c82781483
  xdg.configFile =
    {
      "niri/config.kdl" = mkLiveSymlink "${niriDir}/config.kdl";

      "niri/host.kdl" =
        if hostOutputFile != null
        then mkLiveSymlink "${niriDir}/${hostOutputFile}"
        else {
          text = "// No host-specific output configuration\n";
          force = true;
        };

      "DankMaterialShell/settings.json" = mkLiveSymlink "${dmsConfigDir}/${hostSettingsFile}";
    }
    // xdgConfigDirSymlinks {
      readDirPath = ./config;
      liveDirAbs = dmsConfigDir;
      relPrefix = "DankMaterialShell";
      exclude = settingsBasenames;
    }
    // xdgConfigDirSymlinksPred {
      readDirPath = ../niri;
      liveDirAbs = niriDir;
      relPrefix = "niri";
      predicate = niriPredicate;
    };
}
