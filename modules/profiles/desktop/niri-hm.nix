{
  config,
  host,
  osConfig,
  pkgs,
  ...
}:
let
  inherit (config.lib.dotfiles)
    mkLiveSymlink
    xdgConfigDirSymlinksPred
    ;

  cfg = osConfig.dotfiles.profiles.desktop or { };
  shell = host.desktopShell or cfg.shell or "dms";

  flakeRoot = config.dotfiles.flakeRoot;
  niriDir = "${flakeRoot}/modules/profiles/desktop/niri";

  hostOutputFile = host.niriOutputsFile or null;

  shellSource = if shell == "noctalia" then "shell-noctalia.kdl" else "shell-dms.kdl";

  niriPredicate =
    name:
    name != "config.kdl"
    && builtins.match "outputs-.*\\.kdl" name == null
    && builtins.match "shell(-.*)?\\.kdl" name == null;
in
{
  # Runs niri/overview-catcher.qml (Mod+Space type-to-search).
  home.packages = [ pkgs.quickshell ];

  xdg.configFile = {
    "niri/config.kdl" = mkLiveSymlink "${niriDir}/config.kdl";

    "niri/host.kdl" =
      if hostOutputFile != null then
        mkLiveSymlink "${niriDir}/${hostOutputFile}"
      else
        {
          text = "// No host-specific output configuration\n";
          force = true;
        };

    "niri/shell.kdl" = mkLiveSymlink "${niriDir}/${shellSource}";
  }
  // xdgConfigDirSymlinksPred {
    readDirPath = ./niri;
    liveDirAbs = niriDir;
    relPrefix = "niri";
    predicate = niriPredicate;
  };
}
