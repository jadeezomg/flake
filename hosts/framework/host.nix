let
  inherit (import ../lib.nix) sharedNixOSHost sharedNixOSUser;
in
sharedNixOSHost
// {
  hostname = "framework";
  nixpkgsConfig = {
    rocmSupport = true;
  };
  user = sharedNixOSUser;
  dmsSettingsFile = "settings-framework.json";
  niriOutputsFile = "outputs-framework.kdl";
}
