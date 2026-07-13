# Matrix homeserver (continuwuity) — reachable at https://matrix.jadee.fyi.
#
# continuwuity is the maintained conduwuit successor: a single Rust binary with
# embedded DB (RocksDB under its StateDir). Chosen over Synapse to keep RAM/CPU
# low on this 24 GiB host shared with the local LLM.
#
# Exposure / TLS: continuwuity binds loopback only and is fronted at
# https://matrix.jadee.fyi by the shared Caddy tailnet-node proxy (services/caddy.nix),
# which terminates TLS with a Cloudflare DNS-01 cert. server_name is permanent
# (it suffixes every user/room id): @you:matrix.jadee.fyi.
#
# This server is tailnet-only: federation is OFF, so it never talks to matrix.org
# or the public Matrix network. The Cloudflare A record points at a private
# Tailscale IP (100.x), so only tailnet members can route to it; the public DNS
# entry just lets clients resolve the name + lets Caddy answer the DNS-01 challenge.
#
# Secrets (sops — add the value to secrets/secrets.yaml before switching):
#   matrix_registration_token continuwuity has no CLI user creation; accounts are
#                             made by enabling registration behind this token,
#                             injected as CONTINUWUITY_REGISTRATION_TOKEN (so it
#                             never lands in the world-readable /nix/store config).
#   (Caddy's cloudflare_dns_api_token + tailscale_authkey live in services/caddy.nix.)
#
# ── ONE-TIME BOOTSTRAP (after the first `flake switch` on mini) ──────────────
#   0. Add matrix_registration_token (+ matrix_hermes_password, see hermes.nix) and
#      the Caddy secrets (services/caddy.nix), then switch.
#   1. The mini-proxy Caddy node registers on first boot; create the Cloudflare A
#      record matrix.jadee.fyi → its Tailscale IP (see services/caddy.nix).
#   2. Register the Hermes bot + your account with the token, e.g. against loopback:
#        TOKEN=$(sudo cat /run/secrets/matrix_registration_token)
#        curl -s http://127.0.0.1:6167/_matrix/client/v3/register \
#          -H 'Content-Type: application/json' \
#          -d "{\"username\":\"hermes\",\"password\":\"<matrix_hermes_password>\",
#               \"auth\":{\"type\":\"m.login.registration_token\",\"token\":\"$TOKEN\"},
#               \"inhibit_login\":true}"
#        # then register your own user the same way (or via Element "Create account").
#   3. In Element: homeserver "matrix.jadee.fyi", sign in. Auto-discovery works.
#   4. DM @hermes:matrix.jadee.fyi (it auto-joins on invite; @mention it in rooms).
#   5. (optional) Put a room id in MATRIX_HOME_ROOM (hermes.nix) for cron/notifications.
{ config, ... }:
let
  domain = "matrix.jadee.fyi";
  port = 6167; # continuwuity default; loopback only
in
{
  services.matrix-continuwuity = {
    enable = true;
    settings.global = {
      server_name = domain;
      # Loopback only — Caddy (the tailnet node) terminates TLS and proxies in.
      address = [
        "127.0.0.1"
        "::1"
      ];
      port = [ port ];

      # Registration enabled but gated by the token (CONTINUWUITY_REGISTRATION_TOKEN
      # from the EnvironmentFile below).
      allow_registration = true;

      # Tailnet-only: no federation, no :8448, no notary lookups against matrix.org.
      allow_federation = false;

      # Client discovery: continuwuity serves /.well-known/matrix/client with this
      # base_url, so clients only need the bare "matrix.jadee.fyi".
      well_known.client = "https://${domain}";
    };
  };

  # Registration token → env var, read by systemd (root) before the dynamic user
  # starts, so the 0400 sops secret is readable. Keeps the token out of /nix/store.
  sops.secrets.matrix_registration_token.key = "matrix/registration_token";
  systemd.services.continuwuity.serviceConfig.EnvironmentFile = [
    config.sops.templates."matrix-continuwuity.env".path
  ];
  sops.templates."matrix-continuwuity.env" = {
    mode = "0400";
    content = ''
      CONTINUWUITY_REGISTRATION_TOKEN=${config.sops.placeholder.matrix_registration_token}
    '';
  };

  # Fronted by the shared Caddy tailnet-node proxy (services/caddy.nix): bind to
  # the mini-proxy node + DNS-01 TLS come from the `tsnet` snippet.
  services.caddy.virtualHosts.${domain}.extraConfig = ''
    import tsnet
    reverse_proxy 127.0.0.1:${toString port}
  '';
}
