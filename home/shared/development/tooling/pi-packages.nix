# Declarative pi packages (extensions, skills, prompts, themes).
#
# Pi packages are not executables on $PATH — they are plugins pi loads from
# ~/.pi/agent/ at runtime. So instead of per-package Nix derivations, we just
# declare the list here and let `pi install` wire them up at activation time.
#
# Spec format (anything `pi install` accepts):
#   "npm:@scope/name"               — latest from npm
#   "npm:@scope/name@1.2.3"         — pinned (skipped by `pi update`)
#   "git:github.com/user/repo"      — latest HEAD
#   "git:github.com/user/repo@v1"   — tag / branch / commit
#
# "Always newest" is handled by `just pi-update` which runs `pi update`.
# Activation only ensures declared packages are installed (idempotent via
# `pi list` guard).
#
# See: https://github.com/badlogic/pi-mono/tree/main/packages/coding-agent#pi-packages
{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}: let
  homeDir = config.home.homeDirectory;
  # Pi extensions (installed via `pi install`)
  packages = [
    "npm:pi-agent-browser-native"
    "npm:pi-markdown-preview"
    "npm:pi-openrouter-realtime"
    "npm:pi-connect"
    "npm:pi-mcp-adapter"
  ];

  installScript =
    lib.concatMapStringsSep "\n" (spec: ''
      if ! printf '%s\n' "$installed" | grep -qF ${lib.escapeShellArg spec}; then
        echo "pi-packages: installing ${spec}"
        pi install ${lib.escapeShellArg spec} 2>&1 | sed 's/^/  /' || \
          echo "pi-packages: install failed for ${spec} (will retry next switch)"
      fi
    '')
    packages;
in
  lib.mkIf (osConfig.dotfiles.profiles.devenv.llm.agents.enable or false) {
    home.activation.piPackages = lib.hm.dag.entryAfter ["writeBoundary"] ''
      export HOME=${lib.escapeShellArg homeDir}
      export NPM_CONFIG_PREFIX=${lib.escapeShellArg "${homeDir}/.npm-global"}
      export PATH=${lib.escapeShellArg "${homeDir}/.npm-global/bin"}:${lib.makeBinPath [pkgs.pi-coding-agent pkgs.nodejs pkgs.git pkgs.cacert]}:$PATH
      export NODE_EXTRA_CA_CERTS=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
      mkdir -p ${lib.escapeShellArg "${homeDir}/.npm-global"} ${lib.escapeShellArg "${homeDir}/.pi/agent"}

      ${lib.optionalString (packages != []) ''
        installed=$(pi list 2>/dev/null || true)
        ${installScript}
      ''}
    '';
  }
