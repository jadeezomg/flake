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
  hosts = builtins.mapAttrs validateHost rawHosts;
}
