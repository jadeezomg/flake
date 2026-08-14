{
  dotfilesLib,
  config,
  lib,
  ...
}:
let
  envData = dotfilesLib.shellEnvData;
  paths = dotfilesLib.shellPaths;

  # Sandbox-safe PATH prepend list (wrappers + nix + system + default profile).
  basePathList = [
    paths.nixPaths.wrappersBin
    paths.nixPaths.nixProfile
    paths.nixPaths.userProfile
    paths.nixPaths.systemSw
    paths.nixPaths.defaultProfile
  ];

  basePathColon = lib.concatStringsSep ":" basePathList;

  # nushell doesn't expand `$HOME`/`$USER` in string literals (unlike the
  # bash/zsh double-quoted exports and fish_add_path args below), so resolve the
  # placeholders at eval time before they hit the nushell PATH list — otherwise
  # entries like `/etc/profiles/per-user/$USER/bin` land verbatim and the real
  # per-user profile (where e.g. atuin lives) is missing from a nushell launched
  # without a zsh ancestor. Mirrors the `expand` in essentials/shell-system-env.nix.
  expand = lib.replaceStrings [ "$HOME" "$USER" ] [ config.home.homeDirectory config.home.username ];
  nushellBasePathList = map expand basePathList;

  exportLines = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (k: v: "export ${k}=${lib.escapeShellArg v}") envData.base
  );

  fishSetLines = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (k: v: "set -gx ${k} ${lib.escapeShellArg v}") envData.base
  );

  nushellSetLines = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (k: v: "\$env.${k} = (\$env.${k}? | default ${builtins.toJSON v})") envData.base
  );
in
{
  # Initialization-time exports (mergeable via mkBefore + mkAfter with
  # system.nix). sessionVariables / environmentVariables live in system.nix
  # only, so there's a single source of truth per var without priority wars.
  programs = {
    bash.initExtra = lib.mkBefore ''
      ${exportLines}
      export PATH="${basePathColon}:$PATH"
    '';
    zsh = {
      initContent = lib.mkBefore ''
        ${exportLines}
        export PATH="${basePathColon}:$PATH"
      '';
      profileExtra = lib.mkBefore ''
        export PATH="${basePathColon}:$PATH"
      '';
    };
    fish.interactiveShellInit = lib.mkBefore ''
      ${fishSetLines}
      fish_add_path --prepend --global ${lib.concatStringsSep " " basePathList}
    '';
    nushell.extraEnv = lib.mkBefore ''
      ${nushellSetLines}
      $env.PATH = ($env.PATH | split row (char esep) | prepend [
        ${lib.concatMapStringsSep "\n      " (p: "\"${p}\"") nushellBasePathList}
      ])
    '';
  };
}
