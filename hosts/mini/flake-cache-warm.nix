# Nightly flake update + build + cachix push pipeline.
#
# Architecture (see docs/hosts/mini.md § Known gaps):
#   06:00 Europe/Berlin → git pull → nix flake update → build 3 closures
#     → on success: cachix push + git commit + git push to main
#     → on failure: bisect per-input, push partial result, log held-back inputs
#
# Sops-managed secrets:
#   - mini/git/deploy-key — push-only ed25519 key, registered as a deploy key
#                           on github.com/jadeezomg/flake with write access
#   - cachix/auth-token   — push-scoped token for jadee-flake.cachix.org
{
  config,
  pkgs,
  ...
}:
let
  cacheWarm = pkgs.writeShellApplication {
    name = "flake-cache-warm";
    runtimeInputs = with pkgs; [
      git
      nix
      cachix
      coreutils
      openssh
      jq
    ];
    text = ''
      set -euo pipefail

      REPO_DIR=/var/lib/flake-cache-warm/flake
      CACHIX_NAME=jadee-flake
      REMOTE=git@github.com:jadeezomg/flake.git

      mkdir -p /var/lib/flake-cache-warm

      export GIT_SSH_COMMAND="ssh -i $CREDENTIALS_DIRECTORY/deploy-key -o StrictHostKeyChecking=accept-new -o IdentitiesOnly=yes"
      git config --global user.email "bot@jadee.fyi"
      git config --global user.name  "jadee-mini[bot]"

      if [ ! -d "$REPO_DIR/.git" ]; then
        git clone "$REMOTE" "$REPO_DIR"
      fi
      cd "$REPO_DIR"
      git remote set-url origin "$REMOTE"
      git fetch origin main
      git reset --hard origin/main

      build_all() {
        nix build --no-link --print-build-logs \
          .#nixosConfigurations.mini.config.system.build.toplevel \
          .#nixosConfigurations.desktop.config.system.build.toplevel \
          .#nixosConfigurations.framework.config.system.build.toplevel
      }

      # Capture the input list once before any updates so we can bisect.
      inputs=$(nix flake metadata --json | jq -r '.locks.nodes.root.inputs | keys[]')

      held_back=()

      if nix flake update && build_all; then
        echo "[flake-cache-warm] mass build OK"
      else
        echo "[flake-cache-warm] mass build failed; entering bisect"
        git checkout flake.lock
        for input in $inputs; do
          if nix flake update "$input" && build_all; then
            echo "[flake-cache-warm] kept: $input"
          else
            echo "[flake-cache-warm] held back: $input"
            git checkout flake.lock
            held_back+=("$input")
          fi
        done
      fi

      # Push all closure paths to cachix.
      export CACHIX_AUTH_TOKEN
      CACHIX_AUTH_TOKEN=$(cat "$CREDENTIALS_DIRECTORY/cachix-token")
      nix path-info --recursive \
        .#nixosConfigurations.mini.config.system.build.toplevel \
        .#nixosConfigurations.desktop.config.system.build.toplevel \
        .#nixosConfigurations.framework.config.system.build.toplevel \
        | cachix push "$CACHIX_NAME"

      # Commit + push if the lockfile actually moved.
      if ! git diff --quiet flake.lock; then
        git add flake.lock
        git commit -m "chore(flake): nightly lockfile bump ($(date -I))"
        git push origin main
      fi

      if [ ''${#held_back[@]} -gt 0 ]; then
        echo "[flake-cache-warm] WARNING — held back: ''${held_back[*]}"
      fi
    '';
  };
in
{
  systemd.services.flake-cache-warm = {
    description = "Nightly flake update + build + cachix push";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${cacheWarm}/bin/flake-cache-warm";
      LoadCredential = [
        "deploy-key:${config.sops.secrets."mini/git/deploy-key".path}"
        "cachix-token:${config.sops.secrets."cachix/auth-token".path}"
      ];
      User = "root";
      StateDirectory = "flake-cache-warm";
    };
  };

  systemd.timers.flake-cache-warm = {
    description = "Nightly flake update + build + cachix push";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 06:00:00";
      RandomizedDelaySec = "10m";
      Persistent = true;
    };
  };

  # Secrets are declared unconditionally; sops-nix only decrypts at activation
  # time, not at evaluation, so this evaluates fine even before mini's age key
  # is added to secrets/secrets.yaml. Activation will fail until the secrets
  # are populated — see docs/hosts/mini.md § Known gaps for the bootstrap flow.
  sops.secrets."mini/git/deploy-key" = {
    mode = "0400";
  };
  sops.secrets."cachix/auth-token" = {
    mode = "0400";
  };
}
