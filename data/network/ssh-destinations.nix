# SSH client destinations for `programs.ssh` (home-manager), consumed via
# `dotfilesLib.sshDestinations` in modules/profiles/minimal/network/ssh.nix.
#
# Nothing is written out by hand here and there is no per-host branch: this just
# collects what each machine already declares about itself, so adding a host or
# changing how you reach one is a one-line edit in the file that owns it.
#
#   flake-managed hosts  -> hosts/<name>/host.nix `sshAddress` + `username`,
#                           aggregated (and defaulted to `hostname`) by
#                           hosts/hosts.nix. `sshAddress = null` opts out.
#   everything else      -> data/network/lan-hosts.nix
#
# `lib/default.nix` applies this function with both registries.
#
# These are INTERACTIVE aliases for a human at a terminal, which is why `unraid`
# takes the tailnet name: it works on and off the LAN, and a browser re-auth
# prompt is fine when you are sitting there. Automation wants the opposite
# tradeoff and uses `dotfilesLib.lanHosts.unraid.lan`, because Tailscale SSH's
# re-auth check blocks non-interactive runs — see
# hosts/mini/services/immich-backup.nix.
{ hosts, lanHosts }:
let
  named = builtins.filter (n: hosts.${n}.sshAddress != null) (builtins.attrNames hosts);

  managed = builtins.listToAttrs (
    map (n: {
      name = n;
      value = {
        hostName = hosts.${n}.sshAddress;
        user = hosts.${n}.username;
      };
    }) named
  );
in
{
  destinations = managed // {
    unraid = {
      hostName = lanHosts.unraid.tailnet;
      user = lanHosts.unraid.sshUser;
    };
  };
}
