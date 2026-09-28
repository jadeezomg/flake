# Helpers shared by mini's service modules.
#
# Import with `inherit (import ./lib.nix { inherit lib; }) mkTsnetProxy;`.
{ lib }:
{
  # One Caddy vhost behind the shared `tsnet` snippet (see ./caddy.nix) that
  # reverse proxies to a loopback port. Returns a `services.caddy.virtualHosts`
  # entry, so several calls can be merged with `//`.
  #
  #   mkTsnetProxy { domain = "atuin.jadee.fyi"; port = 8888; }
  #
  # `upstream` replaces the default 127.0.0.1:<port> target. `extra` holds
  # directives placed between `import tsnet` and `reverse_proxy`. Vhosts that
  # need options inside the reverse_proxy block stay hand written.
  mkTsnetProxy =
    {
      domain,
      port ? null,
      upstream ? "127.0.0.1:${toString port}",
      extra ? "",
    }:
    {
      ${domain}.extraConfig = lib.concatLines (
        [ "import tsnet" ]
        ++ lib.optional (extra != "") (lib.removeSuffix "\n" extra)
        ++ [ "reverse_proxy ${upstream}" ]
      );
    };
}
