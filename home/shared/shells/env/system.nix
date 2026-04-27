{
  config,
  lib,
  osConfig,
  ...
}: let
  envData = import ./data.nix;
  paths = import ../core/data/paths.nix;

  flakeRoot = config.dotfiles.flakeRoot;

  # Workstation-only PATH additions on top of the base list from env/base.nix.
  systemPathList = [
    paths.commonPaths.localBin
    paths.commonPaths.cargoBin
    paths.commonPaths.npmGlobalBin
  ];

  systemPathColon = lib.concatStringsSep ":" systemPathList;

  # sessionVariables/environmentVariables is single-source-of-truth when
  # essentials is on: merge base with system overrides so both the
  # sandbox-safe defaults and the workstation overrides show up in .zshenv.
  systemEnv =
    envData.base
    // envData.system
    // {
      FLAKE = flakeRoot;
      NH_FLAKE = flakeRoot;
    };

  exportLines =
    lib.concatStringsSep "\n"
    (lib.mapAttrsToList (k: v: "export ${k}=${lib.escapeShellArg v}")
      systemEnv);

  fishSetLines =
    lib.concatStringsSep "\n"
    (lib.mapAttrsToList (k: v: "set -gx ${k} ${lib.escapeShellArg v}")
      systemEnv);

  zshFlakeFn = ''
    flake() {
      local j="''${FLAKE:?}/Justfile" c
      case "$1" in
        build|switch|generation|gc|fmt|backups)
          [[ $# -le 1 ]] || { c="$1"; shift; command just --justfile "$j" "_$c" "$@"; return }
          ;;
        init)
          [[ $# -le 1 ]] || { shift; command just --justfile "$j" _init "$@"; return }
          ;;
        read-defaults)
          [[ $# -le 1 ]] || { shift; command just --justfile "$j" _read-defaults "$@"; return }
          ;;
      esac
      command just --justfile "$j" "$@"
    }
    nuflake() { command nu "''${FLAKE:?}/build/flake.nu" "$@"; }
    zf() { cd ${flakeRoot}; }
  '';

  bashFlakeFn = ''
    flake() {
      local j="${flakeRoot}/Justfile" c
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
    nuflake() { nu "${flakeRoot}/build/flake.nu" "$@"; }
    zf() { cd ${flakeRoot}; }
  '';

  fishFlakeFn = ''
    function flake
      set -l j "${flakeRoot}/Justfile"
      if test (count $argv) -gt 1
        set -l sub $argv[1]
        if contains $sub build switch generation gc fmt backups
          set -e argv[1]
          just --justfile $j _$sub $argv
          return
        else if test "$sub" = init
          set -e argv[1]
          just --justfile $j _init $argv
          return
        else if test "$sub" = read-defaults
          set -e argv[1]
          just --justfile $j _read-defaults $argv
          return
        end
      end
      just --justfile $j $argv
    end
    function nuflake
      nu "${flakeRoot}/build/flake.nu" $argv
    end
    function zf
      cd ${flakeRoot}
    end
  '';

  nushellFlakeFn = ''
    def --env zf [] { cd $env.FLAKE }
    def --wrapped flake [...rest] {
      ^just --justfile $"($env.FLAKE)/Justfile" ...$rest
    }
    def --wrapped nuflake [...rest] {
      nu $"($env.FLAKE)/build/flake.nu" ...$rest
    }
  '';
in
  lib.mkIf (osConfig.dotfiles.profiles.essentials.enable or true) {
    programs.bash.initExtra = lib.mkAfter ''
      ${exportLines}
      export PATH="${systemPathColon}:$PATH"

      if command -v rbenv >/dev/null 2>&1; then
        eval "$(rbenv init - bash)"
      fi

      ${bashFlakeFn}
    '';

    programs.zsh.sessionVariables = systemEnv;
    programs.zsh.initContent = lib.mkAfter ''
      export PATH="${systemPathColon}:$PATH"

      if command -v rbenv >/dev/null 2>&1; then
        eval "$(rbenv init - zsh)"
      fi

      ${zshFlakeFn}
    '';
    programs.zsh.profileExtra = lib.mkAfter ''
      export PATH="${systemPathColon}:$PATH"
    '';

    programs.fish.interactiveShellInit = lib.mkAfter ''
      ${fishSetLines}
      fish_add_path --append --global ${lib.concatStringsSep " " systemPathList}
      ${fishFlakeFn}
    '';

    programs.nushell.environmentVariables = systemEnv;
    programs.nushell.extraEnv = lib.mkAfter ''
      $env.PATH = ($env.PATH | split row (char esep) | append [
        ${lib.concatMapStringsSep "\n        " (p: "\"${p}\"") systemPathList}
      ])
    '';
    programs.nushell.extraConfig = lib.mkAfter nushellFlakeFn;
  }
