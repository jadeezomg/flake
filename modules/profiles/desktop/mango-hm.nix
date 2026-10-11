{
  config,
  host,
  hostKey,
  lib,
  osConfig,
  ...
}:
let
  inherit (config.lib.dotfiles)
    mkLiveSymlink
    xdgConfigDirSymlinksPred
    ;

  cfg = osConfig.dotfiles.profiles.desktop or { };
  shell = host.desktopShell or cfg.shell or "dms";

  mangoDir = "${config.dotfiles.flakeRoot}/modules/profiles/desktop/mango";
  hostOutputFile = "outputs-${hostKey}.conf";
in
{
  # config.conf loads shell.conf and host.conf with source-optional, so a
  # missing link is fine. DMS has no mango binds yet.
  xdg.configFile =
    lib.optionalAttrs (shell == "noctalia") {
      "mango/shell.conf" = mkLiveSymlink "${mangoDir}/shell-noctalia.conf";
    }
    // lib.optionalAttrs (builtins.pathExists ./mango/${hostOutputFile}) {
      "mango/host.conf" = mkLiveSymlink "${mangoDir}/${hostOutputFile}";
    }
    // xdgConfigDirSymlinksPred {
      readDirPath = ./mango;
      liveDirAbs = mangoDir;
      relPrefix = "mango";
      predicate =
        name:
        builtins.match "outputs-.*\\.conf" name == null && builtins.match "shell-.*\\.conf" name == null;
    };
}
