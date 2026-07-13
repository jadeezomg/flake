# Reusable helpers for xdg.configFile (or home.file) entries that symlink into a
# live checkout via mkOutOfStoreSymlink, so edits apply without a switch.
#
# Prefer `config.dotfiles.flakeRoot` (lib/home/dotfiles.nix) for the repo
# root; pass paths like "''${config.dotfiles.flakeRoot}/path/in/repo" as liveDirAbs.
{ config }:
let
  inherit (config.lib.file) mkOutOfStoreSymlink;

  mkLiveSymlink = target: {
    source = mkOutOfStoreSymlink target;
    force = true;
  };
in
{
  /**
    Pure default when not using the `dotfiles.flakeRoot` option (e.g. tests).
  */
  liveFlakeRoot = homeDirectory: "${homeDirectory}/.dotfiles/flake";

  inherit mkLiveSymlink;

  /**
    Auto-populate config entries from builtins.readDir readDirPath.

    @param readDirPath Path at eval time (e.g. ./config next to the calling module).
    @param liveDirAbs Absolute directory on the running system (symlink targets).
    @param relPrefix Relative path under ~/.config (no leading/trailing slash).
    @param exclude Basenames to omit (e.g. host-specific files linked elsewhere).
  */
  xdgConfigDirSymlinks =
    {
      readDirPath,
      liveDirAbs,
      relPrefix,
      exclude ? [ ],
    }:
    let
      names = builtins.attrNames (builtins.readDir readDirPath);
      keep = builtins.filter (n: !builtins.elem n exclude) names;
      entry = name: {
        name = "${relPrefix}/${name}";
        value = mkLiveSymlink "${liveDirAbs}/${name}";
      };
    in
    builtins.listToAttrs (map entry keep);

  /**
    Same as xdgConfigDirSymlinks but include only names where predicate returns true.
  */
  xdgConfigDirSymlinksPred =
    {
      readDirPath,
      liveDirAbs,
      relPrefix,
      predicate,
    }:
    let
      names = builtins.attrNames (builtins.readDir readDirPath);
      keep = builtins.filter predicate names;
      entry = name: {
        name = "${relPrefix}/${name}";
        value = mkLiveSymlink "${liveDirAbs}/${name}";
      };
    in
    builtins.listToAttrs (map entry keep);
}
