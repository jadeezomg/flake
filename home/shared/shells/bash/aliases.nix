{hostKey ? "framework", ...}: let
  sharedAliases = import ../shared/aliases.nix;
  sharedPaths = import ../shared/paths.nix;
  sharedConfig = import ../shared/config.nix;
  finalHostKey = hostKey;
in {
  # Import common aliases
  programs.bash.shellAliases = sharedAliases.commonAliases;

  # Bash-specific function implementations
  programs.bash.initExtra = ''
    # Quick directory navigation shortcuts
    zz() { cd ${sharedPaths.commonPaths.home}; }
    zc() { cd ${sharedPaths.commonPaths.config}; }
    zd() { cd ${sharedPaths.commonPaths.downloads}; }
    zp() { cd ${sharedPaths.commonPaths.dotfiles}; }
    zf() { cd ${sharedPaths.commonPaths.flake}; }

    # Home Manager shortcuts
    hm() { nix run ${sharedConfig.nixConfig.homeManagerFlake} -- --flake "${sharedPaths.commonPaths.flake}#${finalHostKey}"; }
    hms() { nix run ${sharedConfig.nixConfig.homeManagerFlake} -- switch --flake "${sharedPaths.commonPaths.flake}#${finalHostKey}"; }
    hmn() { nix run ${sharedConfig.nixConfig.homeManagerFlake} -- news --flake "${sharedPaths.commonPaths.flake}#${finalHostKey}"; }

    flake() {
      local j="${sharedPaths.commonPaths.flake}/Justfile" c
      case "$1" in
        build|switch|generation|gc|fmt|backups)
          [[ $# -le 1 ]] || { c="$1"; shift; just --justfile "$j" "_$c" "$@"; return; }
          ;;
        init)
          [[ $# -le 1 ]] || { shift; just --justfile "$j" _init "$@"; return; }
          ;;
        read-defaults)
          [[ $# -le 1 ]] || { shift; just --justfile "$j" _read-defaults "$@"; return; }
          ;;
      esac
      just --justfile "$j" "$@"
    }
    nuflake() { nu "${sharedPaths.commonPaths.flake}/build/flake.nu" "$@"; }
  '';
}
