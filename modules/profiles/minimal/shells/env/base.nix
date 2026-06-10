{
  dotfilesLib,
  lib,
  ...
}: let
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

  exportLines =
    lib.concatStringsSep "\n"
    (lib.mapAttrsToList (k: v: "export ${k}=${lib.escapeShellArg v}")
      envData.base);

  fishSetLines =
    lib.concatStringsSep "\n"
    (lib.mapAttrsToList (k: v: "set -gx ${k} ${lib.escapeShellArg v}")
      envData.base);

  nushellSetLines =
    lib.concatStringsSep "\n"
    (lib.mapAttrsToList (k: v: "\$env.${k} = (\$env.${k}? | default ${builtins.toJSON v})")
      envData.base);
in {
  # Initialization-time exports (mergeable via mkBefore + mkAfter with
  # system.nix). sessionVariables / environmentVariables live in system.nix
  # only, so there's a single source of truth per var without priority wars.
  programs.bash.initExtra = lib.mkBefore ''
    ${exportLines}
    export PATH="${basePathColon}:$PATH"
  '';
  programs.zsh.initContent = lib.mkBefore ''
    ${exportLines}
    export PATH="${basePathColon}:$PATH"
  '';
  programs.zsh.profileExtra = lib.mkBefore ''
    export PATH="${basePathColon}:$PATH"
  '';
  programs.fish.interactiveShellInit = lib.mkBefore ''
    ${fishSetLines}
    fish_add_path --prepend --global ${lib.concatStringsSep " " basePathList}
  '';
  programs.nushell.extraEnv = lib.mkBefore ''
    ${nushellSetLines}
    $env.PATH = ($env.PATH | split row (char esep) | prepend [
      ${lib.concatMapStringsSep "\n      " (p: "\"${p}\"") basePathList}
    ])
  '';
}
