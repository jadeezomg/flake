# Open-WebUI chat frontend for the local chat server, exposed over Tailscale.
# Backend-agnostic: it reads the port from `dotfiles.profiles.llm.serve` and
# auto-discovers the models via /v1/models.
#
# - Open-WebUI listens on loopback only; the shared Caddy tailnet-node proxy
#   (services/caddy.nix) terminates TLS and serves it at https://chat.jadee.fyi
#   (tailnet-only, Cloudflare DNS-01 cert).
# - The chat server is bound to the tailnet too (llm.serve.host = "0.0.0.0"),
#   so other hosts can hit the raw OpenAI API at http://mini:<port>/v1 directly.
#   The firewall keeps both off the public internet via trustedInterfaces=tailscale0
#   (modules/nixos/networking.nix); only :22 is public.
#
# open-webui is unfree ("Open WebUI License") — allowed flake-wide in lib/pkgs.nix.
{ config, lib, ... }:
let
  inherit (import ../lib.nix { inherit lib; }) mkTsnetProxy;
  webuiPort = 8080;
  llmPort = config.dotfiles.profiles.llm.serve.port;
in
{
  services.open-webui = {
    enable = true;
    # Loopback only: Caddy (services/caddy.nix) fronts it with TLS; never public.
    host = "127.0.0.1";
    port = webuiPort;
    environment = {
      # Local OpenAI-compatible chat backend (./default.nix); it runs no auth, so the
      # key is a placeholder open-webui simply forwards. Loopback reaches it whether
      # bound to 0.0.0.0 or 127.0.0.1.
      OPENAI_API_BASE_URL = "http://127.0.0.1:${toString llmPort}/v1";
      OPENAI_API_KEY = "sk-no-auth";
      # No Ollama backend on this host — stop open-webui probing :11434.
      ENABLE_OLLAMA_API = "False";
      # Public URL behind the proxy, so generated links/redirects are correct.
      WEBUI_URL = "https://chat.jadee.fyi";
      # Don't phone home.
      ANONYMIZED_TELEMETRY = "False";
      DO_NOT_TRACK = "True";
      SCARF_NO_ANALYTICS = "True";
    };
  };

  # Fronted by the shared Caddy tailnet-node proxy (services/caddy.nix).
  services.caddy.virtualHosts = mkTsnetProxy {
    domain = "chat.jadee.fyi";
    port = webuiPort;
  };
}
