let
  inherit (import ../lib.nix) sharedNixOSHost sharedNixOSUser;
in
sharedNixOSHost
// {
  hostname = "framework";
  description = "Jadee Framework NixOS Host";
  nixpkgsConfig = {
    rocmSupport = true;
  };
  user = sharedNixOSUser;
  dmsSettingsFile = "settings-framework.json";
  niriOutputsFile = "outputs-framework.kdl";
  mainMonitor = {
    monitorID = "eDP-1";
    monitorResolution = "2880x1920";
    monitorRefreshRate = "120";
    monitorScalingFactor = "2.0";
  };
}
