{
  config,
  host,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.profiles.gaming;
in
{
  config = lib.mkIf cfg.enable {
    programs.gamemode = {
      # GameMode: config via Nix, deployed to /etc/gamemode.ini by the module.
      # https://github.com/NixOS/nixpkgs/blob/nixos-unstable/nixos/modules/programs/gamemode.nix
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
      }
      # Core-parking hints only make sense on X3D parts (dual-CCD cache
      # CPUs); harmful noise elsewhere.
      // lib.optionalAttrs config.dotfiles.hardware.cpu.x3d.enable {
        cpu = {
          amd_x3d_mode_desired = "frequency";
          amd_x3d_mode_default = "cache";
        };
      };
    };

    programs.steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
      gamescopeSession.enable = true;
    };

    environment.systemPackages = with pkgs; [
      steamcmd
      mangohud
      mangojuice
      heroic
      protonup-ng
      protonup-rs
      gamescope-wsi
      wineWow64Packages.staging
      winetricks
    ];

    environment.sessionVariables = {
      STEAM_EXTRA_COMPAT_TOOLS_PATH = "${host.homeDirectory}/.steam/root/compatibilitytools.d";
      WINEPREFIX = "/mnt/storage/Games";
    };
  };
}
