{
  config,
  host,
  hostData,
  lib,
  ...
}:
let
  inherit (config.lib.dotfiles)
    mkLiveSymlink
    xdgConfigDirSymlinks
    ;

  flakeRoot = config.dotfiles.flakeRoot;
  dmsConfigDir = "${flakeRoot}/modules/profiles/desktop/dms/config";

  hostSettingsFile = host.dmsSettingsFile or "settings-desktop.json";
  settingsBasenames = lib.unique (
    builtins.filter (p: p != null) (
      map (h: h.dmsSettingsFile or null) (builtins.attrValues hostData.hosts)
    )
  );
in
{
  xdg.configFile = {
    "DankMaterialShell/settings.json" = mkLiveSymlink "${dmsConfigDir}/${hostSettingsFile}";
  }
  // xdgConfigDirSymlinks {
    readDirPath = ./config;
    liveDirAbs = dmsConfigDir;
    relPrefix = "DankMaterialShell";
    exclude = settingsBasenames;
  };
}
