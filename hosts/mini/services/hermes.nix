{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  # ── hermes-agent npmDepsHash workaround ─────────────────────────────────
  # Upstream hermes-agent ships a stale `npmDepsHash` in nix/lib.nix (verified
  # against every rev incl. HEAD on 2026-06-18): it pins
  #   sha256-m9cjbjzi4SaFCjODfdrawS5e+1ag+MpRn528/upSNqo=
  # but `fetchNpmDeps` on the committed package-lock.json deterministically
  # produces sha256-kbjJ… (invariant across 3 nixpkgs revs + 2 source revs).
  # The bundled hermes-tui build therefore dies with a fixed-output hash
  # mismatch. The hash is a hardcoded literal with no override seam, so we
  # rebuild the package from a hash-patched source — mirroring upstream's own
  # overlays.default (callPackage ./hermes-agent.nix wired with the flake's
  # own inputs) with the single literal corrected. Drop this once upstream
  # ships a correct hash (then `services.hermes-agent.package` can be removed).
  system = pkgs.stdenv.hostPlatform.system;
  hermesSrc = inputs.hermes-agent;
  haInputs = hermesSrc.inputs;

  staleNpmDepsHash = "sha256-m9cjbjzi4SaFCjODfdrawS5e+1ag+MpRn528/upSNqo=";
  realNpmDepsHash = "sha256-kbjJksq7limRIYqP3DwI+GNgCXkG96tXcsQqmuEedxo=";

  hermesSrcPatched = pkgs.runCommand "hermes-agent-src-npmhash-fix" {} ''
    cp -r ${hermesSrc} $out
    chmod -R +w $out
    substituteInPlace $out/nix/lib.nix \
      --replace-fail '${staleNpmDepsHash}' '${realNpmDepsHash}'
  '';

  hermesAgentFixed = pkgs.callPackage "${hermesSrcPatched}/nix/hermes-agent.nix" {
    inherit (haInputs) uv2nix pyproject-nix pyproject-build-systems;
    npm-lockfile-fix = haInputs.npm-lockfile-fix.packages.${system}.default;
    rev = hermesSrc.rev or null;
  };
in {
  services.hermes-agent = {
    enable = true;
    package = hermesAgentFixed;

    addToSystemPackages = true;
    restart = "always";
    restartSec = 5;

    extraPackages = [
      pkgs.kagi-cli
      pkgs.context7
    ];

    # Pulls mautrix[encryption] so the bot can join E2EE rooms on the local
    # continuwuity homeserver (services/matrix.nix).
    extraDependencyGroups = ["matrix" "web"];

    # Matrix bot, non-secret half. Connects over loopback (no TLS on-box) and
    # logs in by password (secret half in hermes.env below). MATRIX_DEVICE_ID is
    # fixed so E2EE keys persist across restarts. The @hermes account is a
    # one-time bootstrap — see services/matrix.nix.
    environment = {
      MATRIX_HOMESERVER = "http://127.0.0.1:6167";
      MATRIX_USER_ID = "@hermes:matrix.jadee.fyi";
      MATRIX_DEVICE_ID = "hermes-mini";
      MATRIX_E2EE_MODE = "optional";
    };

    environmentFiles = [config.sops.templates."hermes.env".path];
  };

  sops.secrets.openrouter_api_key = {};
  sops.secrets.agent_pat = {};
  sops.secrets.hf_token = {};
  sops.secrets.kagi_session_token.key = "kagi/session_token";
  sops.secrets.context7_api_key = {};
  sops.secrets.matrix_hermes_password.key = "matrix/hermes_password";
  sops.templates."hermes.env" = {
    mode = "0400";
    content = ''
      OPENROUTER_API_KEY=${config.sops.placeholder.openrouter_api_key}
      GITHUB_TOKEN=${config.sops.placeholder.agent_pat}
      HF_TOKEN=${config.sops.placeholder.hf_token}
      KAGI_SESSION_TOKEN=${config.sops.placeholder.kagi_session_token}
      CONTEXT7_API_KEY=${config.sops.placeholder.context7_api_key}
      MATRIX_PASSWORD=${config.sops.placeholder.matrix_hermes_password}
    '';
  };

  # ── Un-manage: let the dashboard/CLI write config.yaml ──────────────────────
  # hermes' save_config() no-ops when is_managed() — which is true if HERMES_MANAGED
  # is truthy OR a `.managed` marker exists in HERMES_HOME. The upstream module sets
  # both, making config read-only outside Nix. We deliberately turn that off so the
  # dashboard can persist settings. The activation script still deep-merges the Nix
  # `settings` above into config.yaml on every switch (Nix keys win, everything else
  # is preserved) — so declared keys (model, …) stay declarative and the rest is
  # dashboard-editable. Keep `settings` minimal to maximize what the UI can own.
  systemd.services.hermes-agent.environment.HERMES_MANAGED = lib.mkForce "";

  # Remove the marker the module re-touches each switch (runs after its setup).
  system.activationScripts.hermes-unmanage = {
    deps = ["hermes-agent-setup"];
    text = ''
      _m="${config.services.hermes-agent.stateDir}/.hermes/.managed"
      [ -e "$_m" ] && ${pkgs.coreutils}/bin/unlink "$_m" || true
    '';
  };
}
