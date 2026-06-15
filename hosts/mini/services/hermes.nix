# hermes-agent service config. Native systemd mode (default) — container mode
# only adds value if hermes agents need ad-hoc apt/pip installs at runtime.
#
# Memory: uses Honcho (./honcho.nix) as its native memory provider, joining the
# shared `jadee` workspace so hermes, Claude Code, and omp all read/write the
# same cross-agent memory. hermes runs on mini alongside Honcho, so it talks to
# the loopback API (127.0.0.1:8100) directly — no Tailscale hop. A local baseUrl
# auto-skips API-key auth and auto-enables the provider.
#
# honcho.json carries identity (workspace/peerName/aiPeer) — these keys have no
# env-var fallback in the provider, and the module's `documents` option installs
# into workingDirectory rather than HERMES_HOME, so it's placed via the small
# activation snippet below (resolution priority 1: $HERMES_HOME/honcho.json).
#
# Settings schema otherwise TBD on first run; iterate against the upstream README.
{
  config,
  lib,
  ...
}: let
  cfg = config.services.hermes-agent;
  hermesHome = "${cfg.stateDir}/.hermes";
in {
  services.hermes-agent = {
    enable = true;
    settings = {
      memory.provider = "honcho";
      # Populate model/providers/skills based on hermes-agent README (Phase 2).
    };
    # Pull the `honcho` optional-dependency group (honcho-ai SDK) into the
    # sealed venv — resolved by uv alongside core deps.
    extraDependencyGroups = ["honcho"];
    environmentFiles = lib.optional (config.sops.secrets ? "hermes/env") config.sops.secrets."hermes/env".path;
  };

  # Install honcho.json into HERMES_HOME after the module's own setup activation
  # (which creates the directory). Group-readable like the module's other config.
  system.activationScripts.hermes-honcho-config = lib.stringAfter ["hermes-agent-setup"] ''
    install -o ${cfg.user} -g ${cfg.group} -m 0640 ${./documents/honcho.json} ${hermesHome}/honcho.json
  '';

  # API keys + provider creds — schema iterated as hermes config evolves.
  # Sops secret created lazily; the optional above keeps the service config
  # valid even before the secret exists in secrets.yaml.
  # sops.secrets."hermes/env" = {
  #   mode = "0400";
  # };
}
