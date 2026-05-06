let
  inherit (import ../lib.nix) sharedNixOSHost sharedNixOSUser;
in
  sharedNixOSHost
  // {
    hostname = "mini";
    description = "Mini — Minisforum MS-01 headless server";
    user = sharedNixOSUser;
    # No guest accounts on a headless server.
    extraUsers = [];
    # i5-12600H — 16 threads; leave 4 for daemon/SSH/hermes/etc.
    buildCores = 12;
    stateVersion = "25.11";
    # Note: mainMonitor / dmsSettingsFile / niriOutputsFile intentionally omitted.
    # `home/nixos/default.nix` skips the desktop HM tree when mainMonitor is unset.
  }
