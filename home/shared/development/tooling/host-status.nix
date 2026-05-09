# Installs the `host-status` CLI and background refreshers declared by
# lib/host-status.nix. Cadence and cache paths stay with the Host Status
# cache declaration so readers and schedulers move together.
{
  lib,
  pkgs,
  ...
}: let
  helpers = import ../../../../lib/host-status.nix {inherit pkgs;};
  inherit (helpers) hostStatus credentialCacheSources openrouterRefresh claudeRefresh;
  refreshers = {
    openrouter = openrouterRefresh;
    claude = claudeRefresh;
  };
  cacheSources = lib.mapAttrs (name: source:
    source
    // {
      refresher = refreshers.${name};
    })
  credentialCacheSources;

  # Linux: systemd user timer pair
  mkLinuxTimer = name: source: {
    "host-status-${name}" = {
      Unit.Description = "Refresh ${name} cache for host-status";
      Service = {
        Type = "oneshot";
        ExecStart = "${source.refresher}/bin/${source.refresherName}";
      };
    };
  };

  mkLinuxTimerUnit = name: source: {
    "host-status-${name}" = {
      Unit.Description = "Periodic ${name} cache refresh";
      Timer = {
        OnBootSec = "30s";
        OnUnitActiveSec = "${toString source.intervalSec}s";
        Unit = "host-status-${name}.service";
      };
      Install.WantedBy = ["timers.target"];
    };
  };

  # Darwin: launchd agent
  mkDarwinAgent = source: {
    enable = true;
    config = {
      ProgramArguments = ["${source.refresher}/bin/${source.refresherName}"];
      StartInterval = source.intervalSec;
      RunAtLoad = true;
      KeepAlive = false;
    };
  };
in {
  home.packages = [hostStatus];

  systemd.user.services = lib.mkIf pkgs.stdenv.isLinux (
    lib.mapAttrs' (name: source:
      lib.nameValuePair "host-status-${name}" ((mkLinuxTimer name source)."host-status-${name}"))
    cacheSources
  );

  systemd.user.timers = lib.mkIf pkgs.stdenv.isLinux (
    lib.mapAttrs' (name: source:
      lib.nameValuePair "host-status-${name}" ((mkLinuxTimerUnit name source)."host-status-${name}"))
    cacheSources
  );

  launchd.agents = lib.mkIf pkgs.stdenv.isDarwin (
    lib.mapAttrs' (name: source:
      lib.nameValuePair "host-status-${name}" (mkDarwinAgent source))
    cacheSources
  );
}
