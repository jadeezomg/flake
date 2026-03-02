{
  config,
  lib,
  pkgs,
  hostData,
  hostKey,
  user,
  ...
}: let
  host = hostData.hosts.${hostKey} or {};
in {
  imports = [
    ./hardware-configuration.nix
    ../../modules/shared
    ../../modules/nixos
  ];

  hardware = {
    graphics.enable = true;
    nvidia = {
      open = true;
      nvidiaSettings = true;
      modesetting.enable = true;
    };
  };

  services.xserver.videoDrivers = ["nvidia"];

  # System state version - host specific, don't change, it's used by home-manager to determine the initial version of the system.
  system.stateVersion = "25.11";

  # CUDA cache (NVIDIA builds); appends to shared caches (incl. CachyOS kernel)
  nix.settings = {
    extra-substituters = lib.mkAfter ["https://cache.nixos-cuda.org"];
    extra-trusted-public-keys = lib.mkAfter [
      "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
    ];
  };

  maintenance.garbageCollection = {
    enable = true;
    schedule = "weekly";
    deleteOlderThan = "30d";
  };

  environment.etc."xdg/monitors.xml" = {
    source = ../../data/hosts/desktop/monitors.xml;
    mode = "0644";
  };

  # GDM only reads /var/lib/gdm/.config/monitors.xml; sync our layout there so the
  # login screen uses the same orientation/placement (e.g. HDMI portrait).
  system.activationScripts.gdmMonitors = ''
    mkdir -p /var/lib/gdm/.config
    cp -f ${../../data/hosts/desktop/monitors.xml} /var/lib/gdm/.config/monitors.xml
    chown gdm:gdm /var/lib/gdm/.config/monitors.xml
  '';
}
