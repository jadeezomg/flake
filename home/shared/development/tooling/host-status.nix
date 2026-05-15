# Keep cache cadence with cache paths so readers and schedulers move together.
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

  # openrouter is gated out on Darwin: the refresher would call
  # `op read op://Personal/openrouter_api_key/credential`, which pops the
  # 1Password "exec is trying to access 1Password" prompt every 5 minutes.
  # OpenRouter usage tracking remains Linux-only.
  launchd.agents = lib.mkIf pkgs.stdenv.isDarwin (
    lib.mapAttrs' (name: source:
      lib.nameValuePair "host-status-${name}" (mkDarwinAgent source))
    (lib.filterAttrs (name: _: name != "openrouter") cacheSources)
  );
}
