let
  inherit (import ../lib.nix) sharedNixOSHost sharedNixOSUser;
in
sharedNixOSHost
// {
  hostname = "desktop";
  user = sharedNixOSUser;
  buildCores = 24;
  dmsSettingsFile = "settings-desktop.json";
  niriOutputsFile = "outputs-desktop.kdl";
  gdmMonitorsFile = "monitors-desktop.xml";
}
