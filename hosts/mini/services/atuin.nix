# Atuin sync server — the single shell-history backend for every host.
#
# The server keeps history in postgres. mini already runs one for Immich
# (./immich.nix), so `database.createLocally` adds an `atuin` role and database
# beside it instead of a second instance. Clients set `sync_address` in
# modules/profiles/minimal/shells/core/atuin.nix.
#
# The server binds loopback. The shared Caddy tailnet node (./caddy.nix) fronts
# it at https://atuin.jadee.fyi with a Let's Encrypt cert, so history sync never
# crosses the public internet and needs no open firewall port.
#
# History is end-to-end encrypted with a key that never reaches the server. The
# server sees ciphertext only, which is why no secret is wired in here.
#
# FIRST-RUN ONBOARDING (one-time, in this order):
#   1. Run `flake mini dns-sync` so atuin.jadee.fyi resolves to the proxy node.
#   2. Set `openRegistration = true` below, then `just switch` on mini.
#   3. On one host: `atuin register -u <user> -e <email>`, then `atuin key` and
#      keep the key in 1Password. Registration writes the session locally.
#   4. On every other host: `atuin login -u <user>`, then
#      `atuin key --base64 | atuin import auth` — or paste the key from step 3
#      with `atuin login -u <user> -k <key>`.
#   5. Set `openRegistration = false` again and switch. The server then accepts
#      logins but no new accounts.
{ ... }:
let
  domain = "atuin.jadee.fyi";
  port = 8888; # atuin default; loopback only
in
{
  services.atuin = {
    enable = true;
    host = "127.0.0.1";
    inherit port;
    # Flip to true only for the registration window (see step 2 above).
    openRegistration = true;
    # Postgres role + database beside Immich's; the socket path is the default.
    database.createLocally = true;
  };

  services.caddy.virtualHosts.${domain}.extraConfig = ''
    import tsnet
    reverse_proxy 127.0.0.1:${toString port}
  '';
}
