{
  config,
  host,
  hostData,
  lib,
  ...
}: let
  inherit
    (config.lib.dotfiles)
    mkLiveSymlink
    xdgConfigDirSymlinks
    xdgConfigDirSymlinksPred
    ;

  flakeRoot = config.dotfiles.flakeRoot;
  dmsConfigDir = "${flakeRoot}/modules/profiles/desktop/dms/config";
  niriDir = "${flakeRoot}/modules/profiles/desktop/niri";

  hostSettingsFile = host.dmsSettingsFile or "settings-desktop.json";
  settingsBasenames = lib.unique (
    builtins.filter (p: p != null) (
      map (h: h.dmsSettingsFile or null) (builtins.attrValues hostData.hosts)
    )
  );

  hostOutputFile = host.niriOutputsFile or null;

  niriPredicate = name:
    name != "config.kdl" && builtins.match "outputs-.*\\.kdl" name == null;
in {
  # Auto-symlink configuration files from the flake checkout (live paths).
  # Host-specific filenames come from hosts/<name>/host.nix (dmsSettingsFile, niriOutputsFile).
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
