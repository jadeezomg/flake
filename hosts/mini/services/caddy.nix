# Caddy reverse proxy on its own tailnet node — the single HTTPS front door for
# mini's tailnet services, each under its own *.jadee.fyi subdomain.
#
# Caddy joins the tailnet as a SEPARATE node ("mini-proxy") via the caddy-tailscale
# plugin, so it owns :443 on its own Tailscale IP and never collides with mini's
# own node. Each subdomain gets a real Let's Encrypt cert via the Cloudflare DNS-01
# challenge. Per-service vhosts live in each service's own module
# (services.caddy.virtualHosts.<host>), each `import`ing the shared `tsnet` snippet.
#
#   matrix.jadee.fyi  -> continuwuity   (services/matrix.nix)
#   chat.jadee.fyi    -> open-webui     (services/llm/open-webui.nix)
#   beszel.jadee.fyi  -> beszel hub     (services/beszel.nix)
#
# This replaces the old per-service `tailscale serve` units. After the first switch,
# run `tailscale serve reset` once on mini to clear the now-unused serve config that
# still lingers in tailscaled state (it kept the old mini.quokka-qilin.ts.net URLs).
#
# DNS (split horizon):
#   Tailnet / Cloudflare (`flake mini dns-sync`): A records → mini-proxy Tailscale IP.
#   LAN clients without Tailscale: override the same hostnames → host.miniLanAddress
#   on your router or LAN DNS (Fritz, Unraid, Pi-hole, etc.). Do not point Cloudflare
#   at the RFC1918 address — that breaks off-LAN resolution.
#
# When host.miniCaddyLanEnable is true, `tsnet` also binds the LAN IP so
# https://jellyfin.jadee.fyi (etc.) works on the local network with the same certs.
#
# Secrets (sops — add values to secrets/secrets.yaml before switching):
#   cloudflare_dns_api_token  CF token, Zone->DNS->Edit on the jadee.fyi zone (→ CF_API_TOKEN)
#   tailscale_authkey         reusable, non-ephemeral TS auth key so the node persists (→ TS_AUTHKEY)
{
  config,
  host,
  lib,
  pkgs,
  ...
}:
let
  tsNode = "mini-proxy"; # caddy-tailscale node name + requested tailnet hostname
  lanBind = host.miniLanAddress or "192.168.178.100";
  lanEnable = host.miniCaddyLanEnable or false;
  lanInterface = host.miniLanInterface or "enp2s0f0np0";

  # Caddy built with the tailnet listener + Cloudflare DNS-01 plugins. Both lack
  # the other's transport, so we bundle them. caddy-tailscale has no semver tags
  # upstream → Go pseudo-version from commit bb080c4414ac (2026-01-06). Bump the
  # pins + rerun with lib.fakeHash to refresh `hash` when updating.
  caddyWithPlugins = pkgs.caddy.withPlugins {
    plugins = [
      "github.com/tailscale/caddy-tailscale@v0.0.0-20260106222316-bb080c4414ac"
      "github.com/caddy-dns/cloudflare@v0.2.4"
    ];
    hash = "sha256-TAg2e7r6du1b2CY81x63yGPJ59mjvzdOKcuno+Klaa8=";
  };
in
{
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

    # Shared snippet: tailnet + optional LAN bind, DNS-01 TLS. Services add `reverse_proxy`.
    extraConfig = ''
      (tsnet) {
        bind tailscale/${tsNode}
        ${lib.optionalString lanEnable "bind ${lanBind}"}
        tls {
          dns cloudflare {env.CF_API_TOKEN}
        }
      }
    '';

    # CF_API_TOKEN (DNS-01) + TS_AUTHKEY (node registration).
    environmentFile = config.sops.templates."caddy.env".path;
  };

  networking.firewall.interfaces.${lanInterface} = lib.mkIf lanEnable {
    allowedTCPPorts = [ 443 ];
  };

  # Put the same (plugin) caddy on PATH for on-box ops: `caddy hash-password`,
  # `caddy validate`, `caddy fmt`. The service binary itself is set via package above.
  environment.systemPackages = [ caddyWithPlugins ];

  systemd.services.caddy.restartTriggers = [ config.sops.templates."caddy.env".content ];

  sops = {
    secrets = {
      cloudflare_dns_api_token = { };
      tailscale_authkey = { };

      # Generate with: caddy hash-password --plaintext '<pw>'  → store the hash here.
      hermes_dashboard_basic_auth_hash = { };
    };
    templates."caddy.env" = {
      mode = "0400";
      content = ''
        CF_API_TOKEN=${config.sops.placeholder.cloudflare_dns_api_token}
        TS_AUTHKEY=${config.sops.placeholder.tailscale_authkey}
        HERMES_DASHBOARD_HASH=${config.sops.placeholder.hermes_dashboard_basic_auth_hash}
      '';
    };
  };
}
