# Export every home-manager sops secret as an env var (see age-sops.nix).
# Name rule: secret attr `foo-bar` → `FOO_BAR` (hyphens → underscores, uppercased).
# Extra: if `github-token` present → also set NIX_CONFIG access-tokens from GITHUB_TOKEN.
{
  config,
  lib,
  ...
}: let
  secrets = config.sops.secrets;
  secretNames = lib.attrNames secrets;

  secretToEnvVar = name:
    lib.strings.toUpper (lib.replaceStrings ["-"] ["_"] name);

  resolvePath = name: let
    raw = secrets.${name}.path;
  in
    if lib.hasPrefix "/" raw
    then raw
    else "${config.home.homeDirectory}/${raw}";

  esc = lib.escapeShellArg;

  shPerSecret =
    lib.concatMapStrings (name: let
      p = resolvePath name;
      var = secretToEnvVar name;
    in ''
      if [ -r ${esc p} ]; then
        export ${var}="$(tr -d '[:space:]' <${esc p})"
      fi
    '')
    secretNames;

  shNixConfig = lib.optionalString (lib.elem "github-token" secretNames) ''
    if [ -n "''${GITHUB_TOKEN:-}" ]; then
      export GITHUB_PAT="''${GITHUB_TOKEN}"
      export GITHUB_PERSONAL_ACCESS_TOKEN="''${GITHUB_TOKEN}"
      export NIX_CONFIG="access-tokens = github.com=''${GITHUB_TOKEN} ''${NIX_CONFIG:-}"
    fi
  '';

  shBlock = shPerSecret + shNixConfig;

  fishPerSecret =
    lib.concatMapStrings (name: let
      p = resolvePath name;
      var = secretToEnvVar name;
    in ''
      if test -r ${esc p}
        set -gx ${var} (cat ${esc p} | string trim)
      end
    '')
    secretNames;

  fishNixConfig = lib.optionalString (lib.elem "github-token" secretNames) ''
    if set -q GITHUB_TOKEN
      set -gx GITHUB_PAT $GITHUB_TOKEN
      set -gx GITHUB_PERSONAL_ACCESS_TOKEN $GITHUB_TOKEN
      set -gx NIX_CONFIG "access-tokens = github.com=$GITHUB_TOKEN $NIX_CONFIG"
    end
  '';

  fishBlock = fishPerSecret + fishNixConfig;

  nuPerSecret =
    lib.concatMapStrings (name: let
      p = resolvePath name;
      var = secretToEnvVar name;
      pJson = builtins.toJSON p;
      fileAlias = "${var}_sops_file";
    in ''
      let ${fileAlias} = ${pJson}
      if (''$${fileAlias} | path exists) {
        ''$env.${var} = (''$${fileAlias} | open | str trim)
      }

    '')
    secretNames;

  nuNixConfig = lib.optionalString (lib.elem "github-token" secretNames) ''
    if (($env.GITHUB_TOKEN? | default "") != "") {
      $env.GITHUB_PAT = $env.GITHUB_TOKEN
      $env.GITHUB_PERSONAL_ACCESS_TOKEN = $env.GITHUB_TOKEN
      $env.NIX_CONFIG = "access-tokens = github.com=" + $env.GITHUB_TOKEN + " " + ($env.NIX_CONFIG? | default "")
    }
  '';

  nuBlock = nuPerSecret + nuNixConfig;
in
  lib.mkIf (secretNames != []) {
    programs.bash.initExtra = lib.mkAfter shBlock;
    programs.zsh.initContent = lib.mkAfter shBlock;
    programs.fish.interactiveShellInit = lib.mkAfter fishBlock;
    programs.nushell.extraEnv = lib.mkAfter nuBlock;
  }
