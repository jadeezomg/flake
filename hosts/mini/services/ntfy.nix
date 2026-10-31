# ntfy: push notifications from mini, at https://ntfy.jadee.fyi (tailnet).
#
# Topics:
#   media   imports, health issues, and manual actions from Radarr/Sonarr/Lidarr
#   system  failed units on mini (ntfy-alert@, attached with OnFailure=) and
#           Unraid's notifications (its built-in ntfy.sh agent, user `unraid`)
#
# Users come from the config (NTFY_AUTH_* in a sops template), not from the
# ntfy CLI: `jadee` (admin) for the phone, `mini` (write-only) for services,
# `homepage` (read-only on `system`) for the start page, `unraid` (write-only on
# `system`) for the Unraid server.
# The phone logs in with mini/ntfy/jadee-password from sops; mini only gets
# its hash. Nothing else can read or publish (auth-default-access deny-all).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (import ./lib.nix { inherit lib; }) mkTsnetProxy;
  port = 2586;
  url = "http://127.0.0.1:${toString port}";
  secret = config.sops.placeholder;
in
{
  sops.secrets = {
    "mini/ntfy/jadee-password-hash" = { };
    "mini/ntfy/mini-password-hash" = { };
    "mini/ntfy/mini-token" = { };
    "mini/ntfy/homepage-password-hash" = { };
    "mini/ntfy/homepage-token" = { };
    "mini/ntfy/unraid-password-hash" = { };
    "mini/ntfy/unraid-token" = { };
  };

  # `homepage` reads the system topic for the Homepage ntfy tile
  # (homepage/default.nix). It logs in only with its token.
  sops.templates."ntfy.env" = {
    content = ''
      NTFY_AUTH_USERS='jadee:${secret."mini/ntfy/jadee-password-hash"}:admin,mini:${
        secret."mini/ntfy/mini-password-hash"
      }:user,homepage:${secret."mini/ntfy/homepage-password-hash"}:user,unraid:${
        secret."mini/ntfy/unraid-password-hash"
      }:user'
      NTFY_AUTH_TOKENS='mini:${secret."mini/ntfy/mini-token"}:mini services,homepage:${
        secret."mini/ntfy/homepage-token"
      }:homepage,unraid:${secret."mini/ntfy/unraid-token"}:unraid'
      NTFY_AUTH_ACCESS='mini:media:wo,mini:system:wo,homepage:system:ro,unraid:system:wo'
    '';
    restartUnits = [ "ntfy-sh.service" ];
  };

  services.ntfy-sh = {
    enable = true;
    environmentFile = config.sops.templates."ntfy.env".path;
    settings = {
      base-url = "https://ntfy.jadee.fyi";
      listen-http = "127.0.0.1:${toString port}";
      behind-proxy = true;
      auth-default-access = "deny-all";
      # The phone fetches what it missed while offline.
      cache-duration = "24h";
    };
  };

  services.caddy.virtualHosts = mkTsnetProxy {
    domain = "ntfy.jadee.fyi";
    inherit port;
  };

  # Instanced by OnFailure=ntfy-alert@%n.service. Posts the unit's last log
  # lines to the `system` topic.
  systemd.services."ntfy-alert@" = {
    description = "Send an ntfy alert that %I failed";
    after = [ "ntfy-sh.service" ];
    scriptArgs = "%I";
    serviceConfig = {
      Type = "oneshot";
      DynamicUser = true;
      SupplementaryGroups = [ "systemd-journal" ];
      LoadCredential = [ "token:${config.sops.secrets."mini/ntfy/mini-token".path}" ];
      TimeoutStartSec = "1m";
    };
    path = [
      pkgs.curl
      pkgs.systemd
    ];
    script = ''
      unit=$1
      journalctl -u "$unit" -n 15 --no-pager -o cat | tail -c 3500 \
        | curl -fsS --max-time 20 \
            -K <(printf 'header = "Authorization: Bearer %s"\n' "$(<"$CREDENTIALS_DIRECTORY/token")") \
            -H "Title: $unit failed on mini" \
            -H "Priority: high" \
            -H "Tags: warning" \
            --data-binary @- ${url}/system >/dev/null
    '';
  };
}
