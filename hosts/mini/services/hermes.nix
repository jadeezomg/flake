# hermes-agent service config. Native systemd mode (default) — container mode
# only adds value if hermes agents need ad-hoc apt/pip installs at runtime.
#
# Settings schema TBD on first run; iterate against the upstream README.
{
  config,
  lib,
  ...
}: {
  services.hermes-agent = {
    enable = true;
    settings = {
      # Populate based on hermes-agent README — model, providers, skills, etc.
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
