{
  config,
  lib,
  ...
}: let
  # Pure data shared with minimal's shells tree.
  envData = import ../minimal/shells/env/data.nix;
  paths = import ../minimal/shells/core/data/paths.nix;

  flakeRoot = config.dotfiles.flakeRoot;

  # data.nix and paths.nix use `$HOME`/`$USER` placeholders so shell-init
  # contexts (bash/zsh/fish init blocks rendered into double-quoted shell
  # strings) can rely on POSIX expansion. Anything routed through
  # `lib.escapeShellArg` (single-quoted) or programs.nushell.environmentVariables
  # (no POSIX expansion) loses that, so resolve placeholders at eval time
  # before those values hit such consumers.
  expand = lib.replaceStrings ["$HOME" "$USER"] [config.home.homeDirectory config.home.username];

  # Workstation-only PATH additions on top of the base list from env/base.nix.
  systemPathList = map expand [
    paths.commonPaths.localBin
    paths.commonPaths.cargoBin
    paths.commonPaths.npmGlobalBin
  ];

  systemPathColon = lib.concatStringsSep ":" systemPathList;

  # sessionVariables/environmentVariables is single-source-of-truth when
  # essentials is on: merge base with system overrides so both the
  # sandbox-safe defaults and the workstation overrides show up in .zshenv.
  systemEnv = lib.mapAttrs (_: expand) (
    envData.base
    // envData.system
    // {
      FLAKE = flakeRoot;
      NH_FLAKE = flakeRoot;
    }
  );

  exportLines =
    lib.concatStringsSep "\n"
    (lib.mapAttrsToList (k: v: "export ${k}=${lib.escapeShellArg v}")
      systemEnv);

  fishSetLines =
    lib.concatStringsSep "\n"
    (lib.mapAttrsToList (k: v: "set -gx ${k} ${lib.escapeShellArg v}")
      systemEnv);

  zshFlakeFn = ''
    flake() { command just --justfile "''${FLAKE:?}/Justfile" "$@"; }
    zf() { cd ${flakeRoot}; }
  '';

  bashFlakeFn = ''
    flake() { just --justfile "${flakeRoot}/Justfile" "$@"; }
    zf() { cd ${flakeRoot}; }
  '';

  fishFlakeFn = ''
    function flake
      just --justfile "${flakeRoot}/Justfile" $argv
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
  '';
in {
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
