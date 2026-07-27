# Home-manager options for paths into the live dotfiles checkout (out-of-store
# symlinks, shell helpers, etc.). Override `dotfiles.flakeRoot` if the flake
# lives somewhere other than ~/.dotfiles/flake.
{
  config,
  lib,
  ...
}:
{
  options.dotfiles.flakeRoot = lib.mkOption {
    type = lib.types.str;
    description = ''
      Absolute path to the flake directory on disk (the directory that contains
      `flake.nix`). Used for `mkOutOfStoreSymlink` targets and shell `FLAKE` /
      `NH_FLAKE`. Defaults to ~/.dotfiles/flake.
    '';
  };

  config = {
    dotfiles.flakeRoot = lib.mkDefault "${config.home.homeDirectory}/.dotfiles/flake";

    # HM-native helper channel: any HM module can use
    # `config.lib.dotfiles.mkLiveSymlink` & friends without path imports
    # (same mechanism as config.lib.file.mkOutOfStoreSymlink).
    lib.dotfiles = import ./live-xdg-symlinks.nix { inherit config; };

    # mkOutOfStoreSymlink lands in ~/.config via the HM generation store
    # ($HOME -> $GEN/home-files -> $store -> flake). Repoint to a single hop
    # into the live checkout so edits in git are obvious from readlink/ls.
    home.activation.directFlakeSymlinks = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      flakeRoot=${lib.escapeShellArg config.dotfiles.flakeRoot}
      home=${lib.escapeShellArg config.home.homeDirectory}

      repoint_link() {
        local link="$1"
        local current resolved
        current=$(readlink "$link" 2>/dev/null) || return 0
        case "$current" in
          *home-manager-files*) ;;
          *) return 0 ;;
        esac
        resolved=$(readlink -f "$link" 2>/dev/null) || return 0
        case "$resolved" in
          "$flakeRoot"/*) ;;
          *) return 0 ;;
        esac
        ln -sfn "$resolved" "$link"
      }

      for tree in \
        "$home/.config" \
        "$home/.omp" \
        "$home/Pictures" \
        "$home/.claude" \
        "$home/.agents" \
        ; do
        if [[ -d "$tree" ]]; then
          find "$tree" -type l -print0 2>/dev/null | while IFS= read -r -d $'\0' link; do
            repoint_link "$link"
          done
        fi
      done
    '';
  };
}
