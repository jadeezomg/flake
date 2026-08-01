let
  requiredHostFields = [
    "hostname"
    "system"
    "username"
    "stateVersion"
  ];

  requireHostField =
    hostKey: host: field:
    if builtins.hasAttr field host then
      true
    else
      builtins.throw "Host `${hostKey}` is missing required Host field `${field}`.";

  validateHost =
    hostKey: host: builtins.seq (builtins.all (requireHostField hostKey host) requiredHostFields) host;

  # How to reach a host over ssh, owned by the host itself. Defaults to its own
  # hostname; a host overrides when that is not how you get to it (mini pins a
  # static LAN address) or opts out with `sshAddress = null` (caya). Consumed by
  # data/network/ssh-destinations.nix, so adding a host to the ssh config is a
  # one-line edit in that host's own host.nix rather than a second list here.
  withSshDefault = host: { sshAddress = host.hostname; } // host;

  rawHosts = {
    framework = import ./framework/host.nix;
    desktop = import ./desktop/host.nix;
    caya = import ./caya/host.nix;
    mini = (import ./mini/host.nix) // {
      hostClass = "server";
    };
  };
in
{
  hosts = builtins.mapAttrs (hostKey: host: validateHost hostKey (withSshDefault host)) rawHosts;
}
