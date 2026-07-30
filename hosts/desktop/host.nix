let
  inherit (import ../lib.nix) sharedNixOSHost sharedNixOSUser;
in
sharedNixOSHost
// {
  hostname = "desktop";
  description = "Jadee Desktop NixOS Host";
  user = sharedNixOSUser;
  buildCores = 24;
  dmsSettingsFile = "settings-desktop.json";
  niriOutputsFile = "outputs-desktop.kdl";
  gdmMonitorsFile = "monitors-desktop.xml";
  mainMonitor = {
    monitorID = "DP-2";
    monitorResolution = "2560x1440";
    monitorRefreshRate = "170";
    monitorScalingFactor = "1.0";
  };
}
