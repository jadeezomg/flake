let
  inherit (import ../lib.nix) sharedNixOSHost sharedNixOSUser;
in
  sharedNixOSHost
  // {
    hostname = "framework-nixos";
    description = "Jadee Framework NixOS Host";
    user = sharedNixOSUser;
    dmsSettingsFile = "settings-framework.json";
    niriOutputsFile = "outputs-framework.kdl";
    mainMonitor = {
      monitorID = "eDP-2";
      monitorResolution = "2880x1920";
      monitorRefreshRate = "120";
      monitorScalingFactor = "2.0";
    };
  }
