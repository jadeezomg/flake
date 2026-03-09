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

  environment.systemPackages = with pkgs; [
    nvtopPackages.nvidia
  ];

  # Niri + NVIDIA: limit VRAM usage (driver heap quirk)
  # https://github.com/niri-wm/niri/wiki/Nvidia
  environment.etc."nvidia/nvidia-application-profiles-rc.d/50-limit-free-buffer-pool-in-wayland-compositors.json" = {
    text = ''
      {
        "rules": [
          {
            "pattern": {
              "feature": "procname",
              "matches": "niri"
            },
            "profile": "Limit Free Buffer Pool On Wayland Compositors"
          }
        ],
        "profiles": [
          {
            "name": "Limit Free Buffer Pool On Wayland Compositors",
            "settings": [
              {
                "key": "GLVidHeapReuseRatio",
                "value": 0
              }
            ]
          }
        ]
      }
    '';
    mode = "0644";
  };

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

  # Expose monitors.xml at system XDG path so sessions (and GDM) can use it when looking up
  # XDG_CONFIG_DIRS. See GDM #1028 re monitors.xml compatibility.
  # https://gitlab.gnome.org/GNOME/gdm/-/issues/1028
  environment.etc."xdg/monitors.xml" = {
    source = ../../data/hosts/desktop/monitors.xml;
    mode = "0644";
  };

  # Apply monitor layout to GDM login screen from the flake-managed monitors.xml
  # (GDM 49+ uses /var/lib/gdm/seat0/config). Single source of truth: data/hosts/desktop/monitors.xml
  # https://discourse.nixos.org/t/multi-monitor-gdm-help/60348/6
  systemd.services.applyUserMonitorSettings = let
    gdmConfigDir = "/var/lib/gdm/seat0/config";
    monitorsXml = pkgs.writeText "monitors.xml" (builtins.readFile ../../data/hosts/desktop/monitors.xml);
  in {
    description = "Apply monitor settings to GDM login screen";
    after = ["display-manager.service"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash -c 'mkdir -p ${gdmConfigDir} && cp ${monitorsXml} ${gdmConfigDir}/monitors.xml && chown gdm:gdm ${gdmConfigDir}/monitors.xml'";
    };
  };
}
