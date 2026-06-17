# hermes-agent service config. Native systemd mode (default) — container mode
# only adds value if hermes agents need ad-hoc apt/pip installs at runtime.
#
# Model: routed through OpenRouter (the interactive/complex tier — the local
# mini chat server is reserved for background work like honcho's deriver).
# Default model is DeepSeek V4 Pro; OpenRouter resolves provider routing.
#
# Secrets: `OPENROUTER_API_KEY` comes from `secrets/secrets.yaml` → the
# `openrouter_api_key` sops secret, rendered into an env file via a sops
# template (same pattern as `services/llm/default.nix`). The module
# concatenates `environmentFiles` into `$HERMES_HOME/.env` at activation;
# hermes reads it on every startup via load_hermes_dotenv().
#
# GitHub: `agent_pat` is surfaced as `GITHUB_TOKEN` so the agent can use the
# Skills Hub (install/publish skills from GitHub) and the GitHub API/repos at
# full rate limits. Not needed for inference (that's OpenRouter).
#
# Tool CLIs: `kagi` (web search/summarize) and `ctx7` (Context7 library docs)
# are added to extraPackages so the agent's terminal tool can run them, with
# `KAGI_SESSION_TOKEN` / `CONTEXT7_API_KEY` in .env. Neither is on hermes'
# provider-credential blocklist, so both pass through to the terminal sandbox
# automatically (unlike provider keys, which hermes strips). `HF_TOKEN` is a
# "tool"-category var hermes blocks from subprocesses, but it stays available
# to the main process for HuggingFace downloads / the HF inference provider.
#
# Memory: the Honcho provider wiring was removed 2026-06-16 while evaluating
# alternative memory systems (see docs/adr/0002-honcho-as-shared-agent-memory.md).
# The dormant honcho.json template is kept at ./documents/honcho.json for an easy
# re-enable. To restore: set `settings.memory.provider = "honcho"`,
# `extraDependencyGroups = ["honcho"]`, and install honcho.json into HERMES_HOME.
{
  config,
  pkgs,
  ...
}: {
  services.hermes-agent = {
    enable = true;

    settings = {
      # `model` is a mapping (default/provider/base_url). provider=openrouter
      # makes hermes read OPENROUTER_API_KEY from .env and hit openrouter.ai.
      model = {
        default = "deepseek/deepseek-v4-pro";
        provider = "openrouter";
      };
    };

    # Put the `hermes` CLI on PATH and share HERMES_HOME with the gateway, so
    # `hermes config` / `hermes chat` over SSH operate on the same state.
    addToSystemPackages = true;

    # CLIs the agent can shell out to (terminal tool + cron). Overlay packages
    # from parts/overlays/local-packages.nix.
    extraPackages = [
      pkgs.kagi-cli
      pkgs.context7
    ];

    environmentFiles = [config.sops.templates."hermes.env".path];
  };

  # OpenRouter key → env file consumed by hermes. The secret already lives in
  # secrets/secrets.yaml (decryptable by the mini host key); declaring it here
  # materializes it at runtime. mode 0400 — only the activation script (root)
  # reads the template to seed .env.
  sops.secrets.openrouter_api_key = {};
  sops.secrets.agent_pat = {};
  sops.secrets.hf_token = {};
  sops.secrets.kagi_session_token = {};
  sops.secrets.context7_api_key = {};
  sops.templates."hermes.env" = {
    mode = "0400";
    content = ''
      OPENROUTER_API_KEY=${config.sops.placeholder.openrouter_api_key}
      GITHUB_TOKEN=${config.sops.placeholder.agent_pat}
      HF_TOKEN=${config.sops.placeholder.hf_token}
      KAGI_SESSION_TOKEN=${config.sops.placeholder.kagi_session_token}
      CONTEXT7_API_KEY=${config.sops.placeholder.context7_api_key}
    '';
  };
}
