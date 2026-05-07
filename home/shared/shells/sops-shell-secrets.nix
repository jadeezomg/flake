# Export every home-manager sops secret as an env var (see security.nix).
#
# Name rule: secret attr `foo-bar` → `FOO_BAR` (hyphens → underscores, uppercased).
# Exception: attrs listed in `githubPatSecretAttrs` → `GITHUB_TOKEN` (see security.nix).
#
# Values are read as a single line (`tr` / trim); multi-line secrets are wrong for env vars.
#
# GitHub extras (non-empty token): GITHUB_PAT, GITHUB_PERSONAL_ACCESS_TOKEN, and NIX_CONFIG
# `access-tokens` merged on a new line so existing NIX_CONFIG is preserved.
#
# Wiring: bash `initExtra`, zsh `initContent`, fish `interactiveShellInit`, nushell `extraEnv`.
# See Home Manager for which shell kinds (login vs interactive) run each option — non-interactive
# shells may still load some of this.
{
  config,
  lib,
  ...
}: let
  secrets = config.sops.secrets;
  secretNames = lib.attrNames secrets;

  # Attr names allowed for the GitHub PAT in security.nix (`githubPatSecretAttrName`).
  githubPatSecretAttrs = [
    "github-token"
    "gh-token"
  ];

  secretToEnvVar = name:
    if lib.elem name githubPatSecretAttrs
    then "GITHUB_TOKEN"
    else lib.strings.toUpper (lib.replaceStrings ["-"] ["_"] name);

  hasGithubExtras = lib.any (n: lib.elem n secretNames) githubPatSecretAttrs;

  resolvePath = name: let
    raw = secrets.${name}.path;
  in
    if lib.hasPrefix "/" raw
    then raw
    else "${config.home.homeDirectory}/${raw}";

  secretSpecs =
    builtins.map (name: {
      inherit name;
      path = resolvePath name;
      var = secretToEnvVar name;
    })
    secretNames;

  esc = lib.escapeShellArg;

  shPerSecret =
    lib.concatMapStrings (s: ''
      if [ -r ${esc s.path} ]; then
        export ${s.var}="$(tr -d '[:space:]' <${esc s.path})"
      fi
    '')
    secretSpecs;

  # After per-secret exports, GITHUB_TOKEN is set if a PAT secret was declared.
  shGithubExtras = ''
    if [ -n "''${GITHUB_TOKEN:-}" ]; then
      export GITHUB_PAT="''${GITHUB_TOKEN}"
      export GITHUB_PERSONAL_ACCESS_TOKEN="''${GITHUB_TOKEN}"
      _tok_line="access-tokens = github.com=''${GITHUB_TOKEN}"
      if [ -n "''${NIX_CONFIG:-}" ]; then
        export NIX_CONFIG="''${NIX_CONFIG}"$'\n'"''${_tok_line}"
      else
        export NIX_CONFIG="''${_tok_line}"
      fi
    fi
  '';

  shBlock = shPerSecret + lib.optionalString hasGithubExtras shGithubExtras;

  fishPerSecret =
    lib.concatMapStrings (s: ''
      if test -r ${esc s.path}
        set -gx ${s.var} (cat ${esc s.path} | string trim)
      end
    '')
    secretSpecs;

  fishGithubExtras = ''
    if set -q GITHUB_TOKEN; and test -n "$GITHUB_TOKEN"
      set -gx GITHUB_PAT $GITHUB_TOKEN
      set -gx GITHUB_PERSONAL_ACCESS_TOKEN $GITHUB_TOKEN
      set -l _tok_line "access-tokens = github.com=$GITHUB_TOKEN"
      set -l _nl (printf '\n')
      if set -q NIX_CONFIG; and test -n "$NIX_CONFIG"
        set -gx NIX_CONFIG "$NIX_CONFIG$_nl$_tok_line"
      else
        set -gx NIX_CONFIG $_tok_line
      end
    end
  '';

  fishBlock = fishPerSecret + lib.optionalString hasGithubExtras fishGithubExtras;

  nuPerSecret =
    lib.concatMapStrings (s: let
      pJson = builtins.toJSON s.path;
      fileAlias = "${s.var}_sops_file";
    in ''
      # Nix: prefix with two single quotes + dollar so output is a Nushell `$env` / `$alias` reference.
      let ${fileAlias} = ${pJson}
      if (''$${fileAlias} | path exists) {
        ''$env.${s.var} = (''$${fileAlias} | open | str trim)
      }

    '')
    secretSpecs;

  nuGithubExtras = ''
    if (($env.GITHUB_TOKEN? | default "") != "") {
      let tok = $env.GITHUB_TOKEN
      $env.GITHUB_PAT = $tok
      $env.GITHUB_PERSONAL_ACCESS_TOKEN = $tok
      let tok_line = $"access-tokens = github.com=($tok)"
      $env.NIX_CONFIG = (
        if (($env.NIX_CONFIG? | default "") != "") {
          ($env.NIX_CONFIG | default "") + (char nl) + $tok_line
        } else {
          $tok_line
        }
      )
    }
  '';

  nuBlock = nuPerSecret + lib.optionalString hasGithubExtras nuGithubExtras;
in
  lib.mkIf (secretNames != []) {
    programs.bash.initExtra = lib.mkAfter shBlock;
    programs.zsh.initContent = lib.mkAfter shBlock;
    programs.fish.interactiveShellInit = lib.mkAfter fishBlock;
    programs.nushell.extraEnv = lib.mkAfter nuBlock;
  }
