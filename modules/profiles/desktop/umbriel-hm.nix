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

  umbrielDir = "${config.dotfiles.flakeRoot}/modules/profiles/desktop/umbriel";
  hostOutputFile = "outputs-${hostKey}.toml";
in
{
  # config.toml loads shell.toml and host.toml as optional includes, so a
  # missing link is fine. DMS has no Umbriel binds yet. Noctalia writes
  # noctalia.toml (its color template) next to these links.
  xdg.configFile =
    lib.optionalAttrs (shell == "noctalia") {
      "umbriel/shell.toml" = mkLiveSymlink "${umbrielDir}/shell-noctalia.toml";
    }
    // lib.optionalAttrs (builtins.pathExists ./umbriel/${hostOutputFile}) {
      "umbriel/host.toml" = mkLiveSymlink "${umbrielDir}/${hostOutputFile}";
    }
    // xdgConfigDirSymlinksPred {
      readDirPath = ./umbriel;
      liveDirAbs = umbrielDir;
      relPrefix = "umbriel";
      predicate =
        name:
        builtins.match "outputs-.*\\.toml" name == null && builtins.match "shell-.*\\.toml" name == null;
    };
}
