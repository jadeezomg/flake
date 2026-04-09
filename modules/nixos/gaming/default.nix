{pkgs, ...}: {
  programs = {
    # GameMode: config via Nix, deployed to /etc/gamemode.ini by the module
    # https://github.com/NixOS/nixpkgs/blob/nixos-unstable/nixos/modules/programs/gamemode.nix
    gamemode = {
      enable = true;
      settings = {
        general = {
          reaper_freq = "5";
          desiredgov = "performance";
          desiredprof = "performance";
          softrealtime = "off";
          renice = "0";
          ioprio = "0";
          inhibit_screensaver = "1";
          disable_splitlock = "1";
        };
        cpu = {
          amd_x3d_mode_desired = "frequency";
          amd_x3d_mode_default = "cache";
        };
      };
    };
    steam = {
      enable = true;
      remotePlay.openFirewall = true; # Open ports used by Steam Remote Play
      dedicatedServer.openFirewall = true; # Open ports used by Source Dedicated Server
      gamescopeSession.enable = true;
    };
  };
  environment.systemPackages = with pkgs; [
    steamcmd
    mangohud
    goverlay
    mangojuice
    heroic
    faugus-launcher
    protonup-ng
    protonup-rs
    gamescope-wsi
  ];

  environment.sessionVariables = {
    STEAM_EXTRA_COMPAT_TOOLS_PATH = "/home/jadee/.steam/root/compatibilitytools.d";
  };
}
