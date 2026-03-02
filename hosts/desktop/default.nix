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

  # Apply user monitor settings to login screen by copying the user's monitors.xml
  # to GDM's config directory (GDM 49+ uses /var/lib/gdm/seat0/config).
  # https://discourse.nixos.org/t/multi-monitor-gdm-help/60348/6
  systemd.services.applyUserMonitorSettings = let
    username = user;
    gdmConfigDir = "/var/lib/gdm/seat0/config";
  in {
    description = "Apply user monitor settings to GDM login screen";
    after = ["network.target" "systemd-user-sessions.service" "display-manager.service"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash -c 'echo \"Applying user monitor settings to GDM login screen\" && mkdir -p ${gdmConfigDir} && echo \"Created ${gdmConfigDir} directory\" && [ \"/home/${username}/.config/monitors.xml\" -ef \"${gdmConfigDir}/monitors.xml\" ] || cp /home/${username}/.config/monitors.xml ${gdmConfigDir}/monitors.xml && echo \"Copied monitors.xml to ${gdmConfigDir}/monitors.xml\" && chown gdm:gdm ${gdmConfigDir}/monitors.xml && echo \"Changed ownership of monitors.xml to gdm\"'";
    };
  };
}
