# Pear Desktop (YouTube Music) theme — live-symlinked CSS plus config.json hook.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.lib.dotfiles) mkLiveSymlink;

  flakeRoot = config.dotfiles.flakeRoot;
  pearDesktopCss = "${flakeRoot}/data/files/pear-desktop.css";

  homeDir = config.home.homeDirectory;
  configDir = "${homeDir}/.config/youtube-music";
  themePath = "${configDir}/pear-desktop.css";
  configPath = "${configDir}/config.json";

  esc = lib.escapeShellArg;
in
{
  xdg.configFile."youtube-music/pear-desktop.css" = mkLiveSymlink pearDesktopCss;

  # electron-store keeps user state in config.json; jq-merge only our theme path.
  home.activation.pearDesktopTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    export PATH=${
      lib.makeBinPath [
        pkgs.jq
        pkgs.coreutils
      ]
    }:$PATH
    mkdir -p ${esc configDir}
    if ! jq -e . ${esc configPath} >/dev/null 2>&1; then
      printf '%s\n' '{}' >${esc configPath}
    fi
    tmp=$(mktemp)
    jq --arg theme ${esc themePath} '
      .options //= {} |
      .options.themes //= [] |
      if (.options.themes | index($theme)) then . else .options.themes += [$theme] end
    ' ${esc configPath} >"$tmp" && mv "$tmp" ${esc configPath}
  '';
}
