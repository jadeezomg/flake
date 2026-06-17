# hermes-agent service config. Native systemd mode (default) — container mode
# only adds value if hermes agents need ad-hoc apt/pip installs at runtime.
#
# Memory: the Honcho provider wiring was removed 2026-06-16 while evaluating
# alternative memory systems (see docs/adr/0002-honcho-as-shared-agent-memory.md).
# The dormant honcho.json template is kept at ./documents/honcho.json for an easy
# re-enable. To restore: set `settings.memory.provider = "honcho"`,
# `extraDependencyGroups = ["honcho"]`, and install honcho.json into HERMES_HOME.
#
# Settings schema otherwise TBD on first run; iterate against the upstream README.
{
  config,
  lib,
  ...
}: {
  services.hermes-agent = {
    enable = true;
    settings = {
      # Populate model/providers/skills + memory provider (Phase 2).
    };
    environmentFiles = lib.optional (config.sops.secrets ? "hermes/env") config.sops.secrets."hermes/env".path;
  };

  # API keys + provider creds — schema iterated as hermes config evolves.
  # Sops secret created lazily; the optional above keeps the service config
  # valid even before the secret exists in secrets.yaml.
  # sops.secrets."hermes/env" = {
  #   mode = "0400";
  # };
}
