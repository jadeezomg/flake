# Caddy reverse proxy on its own tailnet node — the single HTTPS front door for
# mini's tailnet services, each under its own *.jadee.fyi subdomain.
#
# Caddy joins the tailnet as a SEPARATE node ("mini-proxy") via the caddy-tailscale
# plugin, so it owns :443 on its own Tailscale IP and never collides with mini's
# own node. Each subdomain gets a real Let's Encrypt cert via the Cloudflare DNS-01
# challenge (no inbound ports — fits the tailnet-only firewall). Per-service vhosts
# live in each service's own module (services.caddy.virtualHosts.<host>), each
# `import`ing the shared `tsnet` snippet (bind to the node + DNS-01 TLS):
#
#   matrix.jadee.fyi  -> continuwuity   (services/matrix.nix)
#   chat.jadee.fyi    -> open-webui     (services/llm/open-webui.nix)
#   beszel.jadee.fyi  -> beszel hub     (services/beszel.nix)
#
# This replaces the old per-service `tailscale serve` units. After the first switch,
# run `tailscale serve reset` once on mini to clear the now-unused serve config that
# still lingers in tailscaled state (it kept the old mini.quokka-qilin.ts.net URLs).
#
# DNS: in Cloudflare, point each subdomain (A record, proxy OFF) at the mini-proxy
# node's Tailscale IP — find it post-deploy with `tailscale status | grep mini-proxy`.
# All subdomains share that one IP. The public record just resolves the name and lets
# Caddy answer DNS-01; only tailnet members can route to the private 100.x address.
#
# Secrets (sops — add values to secrets/secrets.yaml before switching):
#   cloudflare_dns_api_token  CF token, Zone->DNS->Edit on the jadee.fyi zone (→ CF_API_TOKEN)
#   tailscale_authkey         reusable, non-ephemeral TS auth key so the node persists (→ TS_AUTHKEY)
{
  config,
  pkgs,
  ...
}: let
  tsNode = "mini-proxy"; # caddy-tailscale node name + requested tailnet hostname

  # Caddy built with the tailnet listener + Cloudflare DNS-01 plugins. Both lack
  # the other's transport, so we bundle them. caddy-tailscale has no semver tags
  # upstream → Go pseudo-version from commit bb080c4414ac (2026-01-06). Bump the
  # pins + rerun with lib.fakeHash to refresh `hash` when updating.
  caddyWithPlugins = pkgs.caddy.withPlugins {
    plugins = [
      "github.com/tailscale/caddy-tailscale@v0.0.0-20260106222316-bb080c4414ac"
      "github.com/caddy-dns/cloudflare@v0.2.4"
    ];
    hash = "sha256-yv1KAogovEJWMSUACcNH0aklHahVXx9HmsJgT8ASmWI=";
  };
in {
  services.caddy = {
    enable = true;
    package = caddyWithPlugins;

    # caddy-tailscale node. auth_key comes from TS_AUTHKEY (env file below);
    # state_dir persists the node identity under the caddy StateDirectory so the
    # key is only needed on first run.
    globalConfig = ''
      tailscale {
        ephemeral false
        state_dir ${config.services.caddy.dataDir}/tsnet
        ${tsNode} {
          hostname ${tsNode}
        }
      }
    '';

    # Shared snippet imported by every tailnet vhost: bind to the mini-proxy node
    # and obtain the cert via Cloudflare DNS-01. Services then add `reverse_proxy`.
    extraConfig = ''
      (tsnet) {
        bind tailscale/${tsNode}
        tls {
          dns cloudflare {env.CF_API_TOKEN}
        }
      }
    '';

    # CF_API_TOKEN (DNS-01) + TS_AUTHKEY (node registration).
    environmentFile = config.sops.templates."caddy.env".path;
  };

  # Put the same (plugin) caddy on PATH for on-box ops: `caddy hash-password`,
  # `caddy validate`, `caddy fmt`. The service binary itself is set via package above.
  environment.systemPackages = [caddyWithPlugins];

  # The module reloads caddy on config change, but `systemctl reload` does NOT
  # re-read EnvironmentFile. When the env-var SET changes (e.g. adding
  # HERMES_DASHBOARD_HASH), a reload leaves the running process without the new
  # var → `{env.…}` resolves empty and the reload fails. Force a full restart
  # whenever the env template's shape changes so the new vars are loaded.
  systemd.services.caddy.restartTriggers = [config.sops.templates."caddy.env".content];

  sops.secrets.cloudflare_dns_api_token = {};
  sops.secrets.tailscale_authkey = {};
  # bcrypt hash gating the Hermes dashboard vhost (services/hermes-dashboard.nix).
  # Generate with: caddy hash-password --plaintext '<pw>'  → store the hash here.
  sops.secrets.hermes_dashboard_basic_auth_hash = {};
  sops.templates."caddy.env" = {
    mode = "0400";
    content = ''
      CF_API_TOKEN=${config.sops.placeholder.cloudflare_dns_api_token}
      TS_AUTHKEY=${config.sops.placeholder.tailscale_authkey}
      HERMES_DASHBOARD_HASH=${config.sops.placeholder.hermes_dashboard_basic_auth_hash}
    '';
  };
}
