{
  config,
  lib,
  pkgs,
  ...
}: {
  hardware.nvidia = {
    open = true;
    package = config.boot.kernelPackages.nvidiaPackages.beta;
    nvidiaSettings = true;
    modesetting.enable = true;
  };
  hardware.nvidia-container-toolkit.enable = true;

  services.xserver.videoDrivers = ["nvidia"];

  environment.systemPackages = with pkgs; [nvtopPackages.nvidia];

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

  # CUDA cache (NVIDIA builds); appends to shared caches (incl. CachyOS kernel)
  nix.settings = {
    extra-substituters = lib.mkAfter ["https://cache.nixos-cuda.org"];
    extra-trusted-public-keys = lib.mkAfter [
      "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
    ];
  };
}
