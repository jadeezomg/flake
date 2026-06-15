# Open-WebUI chat frontend for the local chat server, exposed over Tailscale.
# Backend-agnostic: it talks to the shared contract (host.miniLlm{Port,Host}) and
# auto-discovers the model via /v1/models, so it is unaffected by whether vllm or
# llamacpp is the active backend.
#
# - Open-WebUI listens on loopback only; `tailscale serve` terminates TLS at the
#   tailnet MagicDNS name and proxies to it, so the UI is reachable at
#   https://mini.quokka-qilin.ts.net (tailnet-only, valid auto-renewed cert).
# - The chat server is bound to the tailnet too (host.miniLlmHost = "0.0.0.0"),
#   so other hosts can hit the raw OpenAI API at http://mini:<port>/v1 directly.
#   The firewall keeps both off the public internet via trustedInterfaces=tailscale0
#   (modules/nixos/networking.nix); only :22 is public.
#
# open-webui is unfree ("Open WebUI License") — allowed flake-wide in lib/pkgs.nix.
{
  config,
  host,
  ...
}: let
  webuiPort = 8080;
  tsName = "mini.quokka-qilin.ts.net";
  tailscale = config.services.tailscale.package;
in {
  services.open-webui = {
    enable = true;
    # Loopback only: tailscale serve fronts it with TLS; never opened publicly.
    host = "127.0.0.1";
    port = webuiPort;
    environment = {
      # Local OpenAI-compatible chat backend (shared contract, host.nix); it runs no
      # auth, so the key is a placeholder open-webui simply forwards. Loopback reaches
      # it whether bound to 0.0.0.0 or 127.0.0.1.
      OPENAI_API_BASE_URL = "http://127.0.0.1:${toString host.miniLlmPort}/v1";
      OPENAI_API_KEY = "sk-no-auth";
      # No Ollama backend on this host — stop open-webui probing :11434.
      ENABLE_OLLAMA_API = "False";
      # Public URL behind the proxy, so generated links/redirects are correct.
      WEBUI_URL = "https://${tsName}";
      # Don't phone home.
      ANONYMIZED_TELEMETRY = "False";
      DO_NOT_TRACK = "True";
      SCARF_NO_ANALYTICS = "True";
    };
  };

  # HTTPS on the tailnet. `tailscale serve --bg` persists in tailscaled state; this
  # oneshot (re)asserts the mapping after tailscaled and open-webui are up.
  systemd.services.tailscale-serve-open-webui = {
    description = "Tailscale Serve: HTTPS -> Open-WebUI";
    after = ["tailscaled.service" "open-webui.service"];
    wants = ["tailscaled.service"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${tailscale}/bin/tailscale serve --bg --yes http://127.0.0.1:${toString webuiPort}";
      ExecStop = "${tailscale}/bin/tailscale serve reset";
    };
  };
}
