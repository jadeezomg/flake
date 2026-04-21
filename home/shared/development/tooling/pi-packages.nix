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
#   "https://github.com/user/repo"  — via https
#   "ssh://git@github.com/user/repo"
#
# "Always newest" is handled by `just pi-update` which runs `pi update`.
# Activation only ensures declared packages are installed (idempotent via
# `pi list` guard).
#
# See: https://github.com/badlogic/pi-mono/tree/main/packages/coding-agent#pi-packages
{
  lib,
  pkgs,
  ...
}: let
  pi-coding-agent = pkgs.callPackage ../../../../packages/pi-coding-agent {};

  packages = [
    # "npm:@mariozechner/pi-example-tools"
    # "git:github.com/badlogic/pi-mono"
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
in {
  # Ensure declared pi packages are installed after each switch.
  home.activation.piPackages = lib.hm.dag.entryAfter ["writeBoundary"] (
    if packages == []
    then ":" # no-op
    else
      ''
        export PATH=${lib.makeBinPath [pi-coding-agent pkgs.nodejs pkgs.git pkgs.cacert]}:$PATH
        export NODE_EXTRA_CA_CERTS=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
        mkdir -p "$HOME/.pi/agent"

        installed=$(pi list 2>/dev/null || true)
      ''
      + installScript
  );
}
