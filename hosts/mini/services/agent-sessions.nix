# Agent session archive. Plan and decisions: docs/agents/session-management-plan.md.
#
# Hosts push their agent session files to /srv/agent-sessions/<host>/<agent>/
# (modules/profiles/devenv/agents/session-push.nix, every 15 minutes). agentsview
# indexes the archive and serves it at https://sessions.jadee.fyi. restic backs
# the archive up to Unraid every night.
#
# PUSH RECEIVER. OpenSSH listens on `host.agentPushPort` (2222) as well as 22.
# The firewall opens 2222 only on tailscale0, which is trusted. Port 22 on the
# tailnet address belongs to Tailscale SSH, and Tailscale SSH ignores the forced
# command below. Each key in hosts/<host>/host.nix `agentPushKey` can only run
# `rrsync -wo -no-del /srv/agent-sessions/<host>`: write into its own folder.
# No reads, no deletes, no shell, no forwarding.
#
# HERMES. A timer copies hermes' state.db into /srv/agent-sessions/mini-hermes/
# every 15 minutes. It runs as the hermes user. When sqlite3 runs as root while
# hermes is down, it can create root-owned -wal/-shm files next to state.db.
# hermes then fails to open its own database.
#
# AGENTSVIEW. Runs as the system user agentsview in the agent-sessions group. It
# reads the archive and nothing in /home. Not DynamicUser: that makes
# /var/lib/agentsview a symlink, and agentsview then cannot write its runtime
# record there. agentsview writes generated secrets into its own
# config.toml, so the unit writes that file from the Nix template at each start
# and keeps the generated lines. Login: Caddy basic_auth with the hermes
# dashboard credentials (hermes_dashboard_basic_auth_hash). agentsview's own
# auth stays off, because it listens on loopback only.
#
# BACKUP. restic over SFTP to Unraid, same transport as ./immich-backup.nix,
# with its own repo and password. agentsview's database is not in the backup:
# it is an index that agentsview rebuilds from the archive.
#
# ONE-TIME STEPS before the first switch:
#   1. `sops secrets/secrets.yaml`: add mini/backup/agent-sessions-restic-password
#      (a long random string). A missing key fails the switch.
#   2. On Unraid, in a shell there: mkdir -p /mnt/user/backup/agent-sessions
#   3. After the switch: `flake mini dns-sync` for sessions.jadee.fyi.
{
  config,
  dotfilesLib,
  host,
  lib,
  pkgs,
  ...
}:
let
  inherit (import ./lib.nix { inherit lib; }) mkTsnetProxy;
  inherit (dotfilesLib.lanHosts) unraid;

  root = "/srv/agent-sessions";
  group = "agent-sessions";
  domain = "sessions.jadee.fyi";
  port = 8089;
  stateDir = "/var/lib/agentsview";
  agentsview = pkgs.llm-agents.agentsview;

  # Hosts whose push key is registered, keyed by host key.
  pushers = lib.filterAttrs (_: h: h ? agentPushKey) dotfilesLib.hostFacts;

  hermes = config.services.hermes-agent;
  hermesDir = "${root}/mini-hermes/hermes";

  # mini's own folders count as local, so agentsview labels them with
  # `local_machine_name` instead of a remote machine key.
  sourceOf =
    hostKey: name: src:
    {
      agent = src.parser;
      dir = "${root}/${hostKey}/${name}";
    }
    // lib.optionalAttrs (hostKey != "mini") { machine = hostKey; };

  configTemplate = (pkgs.formats.toml { }).generate "agentsview-config.toml" {
    disable_update_check = true;
    local_machine_name = "mini";
    # Must match the origin Caddy serves, or agentsview rejects the request.
    public_url = "https://${domain}";
    session_sources =
      lib.concatLists (
        lib.mapAttrsToList (
          hostKey: _: lib.mapAttrsToList (sourceOf hostKey) dotfilesLib.agentSessionSources
        ) pushers
      )
      ++ lib.optional hermes.enable {
        agent = "hermes";
        dir = hermesDir;
      };
  };

  # Top-level TOML keys must come before the first table, so the kept lines go
  # first.
  writeConfig = pkgs.writeShellScript "agentsview-write-config" ''
    set -euo pipefail
    cfg="$STATE_DIRECTORY/config.toml"
    kept=""
    if [[ -f $cfg ]]; then
      kept=$(${pkgs.gnugrep}/bin/grep -E '^(cursor_secret|auth_token)[[:space:]]*=' "$cfg" || true)
    fi
    {
      [[ -n $kept ]] && printf '%s\n' "$kept"
      cat ${configTemplate}
    } >"$cfg.new"
    chmod 0600 "$cfg.new"
    mv -f "$cfg.new" "$cfg"
  '';

  hermesSnapshot = pkgs.writeShellApplication {
    name = "agent-sessions-hermes-snapshot";
    runtimeInputs = with pkgs; [
      coreutils
      sqlite
    ];
    text = ''
      src=${lib.escapeShellArg "${hermes.stateDir}/.hermes/state.db"}
      tmp=${lib.escapeShellArg "${hermesDir}/.state.db.tmp"}
      if [[ ! -f $src ]]; then
        echo "agent-sessions-hermes-snapshot: no $src yet"
        exit 0
      fi
      rm -f "$tmp"
      sqlite3 "$src" ".backup '$tmp'"
      # agentsview opens the snapshot read-only and cannot read WAL mode that way.
      sqlite3 "$tmp" "PRAGMA journal_mode=DELETE;" >/dev/null
      chmod 0640 "$tmp"
      mv -f "$tmp" ${lib.escapeShellArg "${hermesDir}/state.db"}
    '';
  };

  # restic's sftp backend reads everything from ssh_config (see ./immich-backup.nix).
  sshAlias = "unraid-backup-agent-sessions";
  sshStateDir = "/var/lib/agent-sessions-backup";
in
{
  users = {
    groups = {
      ${group} = { };
      agentsview = { };
    };

    users.agentsview = {
      isSystemUser = true;
      group = "agentsview";
      extraGroups = [ group ];
    };

    # Push receiver: the forced command limits each host key to its own folder.
    users.agent-push = {
      isSystemUser = true;
      inherit group;
      home = root;
      # sshd runs the forced command through the login shell.
      shell = pkgs.bashInteractive;
      openssh.authorizedKeys.keys = lib.mapAttrsToList (
        hostKey: h:
        ''restrict,command="${pkgs.rrsync}/bin/rrsync -wo -no-del ${root}/${hostKey}" ${h.agentPushKey}''
      ) pushers;
    };
  };

  services = {
    openssh = {
      ports = [
        22
        host.agentPushPort
      ];
      # Port 22 stays open on the LAN through modules/nixos/networking.nix.
      # Without this, NixOS opens every port in `ports` on every interface.
      openFirewall = false;
      settings.AllowUsers = [ "agent-push" ];
    };

    caddy.virtualHosts = mkTsnetProxy {
      inherit domain port;
      extra = ''
        basic_auth {
          jadee {env.HERMES_DASHBOARD_HASH}
        }
      '';
    };

    restic.backups.agent-sessions = {
      repository = "sftp:${sshAlias}:${unraid.shareRoot}/backup/agent-sessions";
      passwordFile = config.sops.secrets."mini/backup/agent-sessions-restic-password".path;
      initialize = true;
      paths = [ root ];
      # Staging folders of `rsync --delay-updates` while a push runs.
      exclude = [ ".~tmp~" ];
      extraBackupArgs = [ "--tag agent-sessions" ];
      # The repo is small, so prune runs with every backup.
      pruneOpts = [
        "--tag agent-sessions"
        "--keep-daily 14"
        "--keep-weekly 8"
        "--keep-monthly 24"
      ];
      timerConfig = {
        OnCalendar = "*-*-* 03:45:00";
        RandomizedDelaySec = "15m";
        Persistent = true;
      };
    };
  };

  systemd = {
    # The root folder belongs to root. systemd-tmpfiles refuses to step from a
    # folder of an unprivileged user into a folder of root, such as
    # mini-hermes. agent-push owns only the folder of each host.
    tmpfiles.settings.agent-sessions = {
      ${root}.d = {
        user = "root";
        inherit group;
        mode = "2750";
      };
      "${root}/mini-hermes".d = {
        user = "root";
        inherit group;
        mode = "2750";
      };
      ${hermesDir}.d = {
        inherit (hermes) user;
        inherit group;
        mode = "2750";
      };
      ${sshStateDir}.d = {
        user = "root";
        group = "root";
        mode = "0700";
      };
    }
    // lib.mapAttrs' (
      hostKey: _:
      lib.nameValuePair "${root}/${hostKey}" {
        d = {
          user = "agent-push";
          inherit group;
          mode = "2750";
        };
      }
    ) pushers;

    services = {
      agent-sessions-hermes = lib.mkIf hermes.enable {
        description = "Copy hermes state.db into the agent session archive";
        serviceConfig = {
          Type = "oneshot";
          User = hermes.user;
          Group = hermes.group;
          # Search access to /srv/agent-sessions.
          SupplementaryGroups = [ group ];
          ExecStart = lib.getExe hermesSnapshot;
          ProtectSystem = "strict";
          ReadWritePaths = [ hermesDir ];
          PrivateTmp = true;
          NoNewPrivileges = true;
        };
      };

      agentsview = {
        description = "agentsview: search and web UI for the agent session archive";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        environment = {
          AGENTSVIEW_DATA_DIR = stateDir;
          HOME = stateDir;
          AGENTSVIEW_TELEMETRY_ENABLED = "0";
          AGENTSVIEW_DISABLE_UPDATE_CHECK = "1";
        };
        serviceConfig = {
          User = "agentsview";
          Group = "agentsview";
          StateDirectory = "agentsview";
          StateDirectoryMode = "0700";
          ExecStartPre = writeConfig;
          ExecStart = "${agentsview}/bin/agentsview serve --host 127.0.0.1 --port ${toString port} --no-browser --no-update-check";
          Restart = "on-failure";
          RestartSec = 10;
          # agentsview sets a 256 MiB soft limit for Go. This is the hard stop.
          MemoryMax = "1G";
          ProtectSystem = "strict";
          ProtectHome = true;
          ReadOnlyPaths = [ root ];
          PrivateTmp = true;
          PrivateDevices = true;
          NoNewPrivileges = true;
        };
      };

      restic-backups-agent-sessions = {
        onFailure = [ "ntfy-alert@%n.service" ];
        serviceConfig = {
          ReadWritePaths = [ sshStateDir ];
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateDevices = true;
          CPUSchedulingPolicy = "batch";
          IOSchedulingClass = "best-effort";
          IOSchedulingPriority = 7;
        };
      };
    };

    timers.agent-sessions-hermes = lib.mkIf hermes.enable {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*:0/15";
        Persistent = true;
      };
    };
  };

  # restic's sftp backend takes host, user and key from ssh_config only.
  programs.ssh.extraConfig = ''

    Host ${sshAlias}
      HostName ${unraid.lan}
      User ${unraid.sshUser}
      IdentityFile ${config.sops.secrets."mini/backup/unraid-ssh-key".path}
      IdentitiesOnly yes
      StrictHostKeyChecking accept-new
      UserKnownHostsFile ${sshStateDir}/known_hosts
      ServerAliveInterval 30
      ServerAliveCountMax 6
  '';

  # Declared again here, so the backup does not depend on ./immich-backup.nix.
  sops.secrets = {
    "mini/backup/unraid-ssh-key".mode = "0400";
    "mini/backup/agent-sessions-restic-password".mode = "0400";
  };
}
