# Secrets that more than one mini service reads. Declared here once, imported
# unconditionally from ./default.nix, so a consumer never depends on another
# optional module for its `config.sops.placeholder.*`.
#
#   hf_token                          hermes.nix (hermes.env) and the llama.cpp
#                                     router (mini-llm-hf.env, services/llm/).
#   hermes_dashboard_basic_auth_hash  caddy.nix renders it into caddy.env; the
#                                     hermes.jadee.fyi vhost in hermes-dashboard.nix
#                                     reads it as {env.HERMES_DASHBOARD_HASH}.
#
# Per-service secrets stay next to their service. Values live in
# secrets/secrets.yaml.
{ config, ... }:
{
  sops = {
    secrets = {
      hf_token = { };
      # Generate with: caddy hash-password --plaintext '<pw>'  then store the hash.
      hermes_dashboard_basic_auth_hash = { };
    };

    # Hugging Face Hub auth for llama-server downloads (rate limits, gated repos).
    templates."mini-llm-hf.env" = {
      mode = "0400";
      content = ''
        HF_TOKEN=${config.sops.placeholder.hf_token}
        HUGGING_FACE_HUB_TOKEN=${config.sops.placeholder.hf_token}
      '';
    };
  };
}
