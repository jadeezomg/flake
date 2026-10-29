# Push this host's agent session files to the archive on mini
# (hosts/mini/services/agent-sessions.nix). Plan and decisions:
# docs/agents/session-management-plan.md.
#
# A systemd user timer runs every 15 minutes. rsync sends each folder from
# `dotfilesLib.agentSessionSources` over SSH to mini's tailnet name on port
# 2222. mini forces `rrsync -wo -no-del /srv/agent-sessions/<host>` for this
# key, so the key can only write into this host's folder. The push never
# deletes: a session that an agent removes here stays in the archive.
#
# FIRST RUN (once per host):
#   1. Switch this host. Activation makes ~/.ssh/agent_push_ed25519 if it is
#      missing.
#   2. Put the public key into hosts/<host>/host.nix as `agentPushKey`.
#   3. Switch mini, then this host. The timer exists only when the key is set.
#
# Linux only. caya is out of scope: work sessions stay off mini.
{
  config,
  dotfilesLib,
  host,
  hostKey,
  isDarwin,
  lib,
  pkgs,
  ...
}:
let
  inherit (dotfilesLib.hostFacts) mini;
  home = config.home.homeDirectory;
  keyFile = "${home}/.ssh/agent_push_ed25519";

  ssh = lib.concatStringsSep " " [
    "ssh"
    "-p ${toString mini.agentPushPort}"
    "-i ${keyFile}"
    "-o IdentitiesOnly=yes"
    "-o BatchMode=yes"
    "-o ConnectTimeout=20"
    # mini's host key is not in the flake, so trust it on first use. The
    # separate file keeps this out of the interactive known_hosts.
    "-o StrictHostKeyChecking=accept-new"
    "-o UserKnownHostsFile=${home}/.ssh/known_hosts_agent_push"
  ];

  # One block per source. `name` is the folder under /srv/agent-sessions/<host>.
  pushSource =
    name: src:
    let
      dir = "${home}/${src.path}";
      excludes = lib.concatMapStringsSep " " (p: "--exclude=${lib.escapeShellArg p}") (
        src.exclude or [ ]
      );
    in
    ''
      if [[ -d ${lib.escapeShellArg dir} ]]; then
        send ${lib.escapeShellArg dir} ${name} ${excludes} || failed+=(${name})
      fi
    '';

  push = pkgs.writeShellApplication {
    name = "agent-session-push";
    runtimeInputs = with pkgs; [
      coreutils
      openssh
      rsync
    ];
    text = ''
      failed=()

      # send <local dir> <archive folder> [rsync args...]
      # No -p/-o/-g from the source: mini sets group-readable modes, so that
      # agentsview can read the files through the agent-sessions group.
      send() {
        local src=$1 dest=$2
        shift 2
        rsync --recursive --links --times --perms --chmod=D2750,F640 \
          --delay-updates --timeout=120 "$@" \
          -e ${lib.escapeShellArg ssh} \
          "$src/" "agent-push@${mini.tailnetAddress}:$dest/"
      }

      ${lib.concatStrings (lib.mapAttrsToList pushSource dotfilesLib.agentSessionSources)}
      if ((''${#failed[@]})); then
        echo "agent-session-push: failed: ''${failed[*]}" >&2
        exit 1
      fi
    '';
  };
in
lib.mkIf (!isDarwin) (
  lib.mkMerge [
    {
      # The key has no passphrase, because a timer uses it. mini limits it to
      # write-only rsync into this host's folder.
      home.activation.agentPushKey = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        if [[ ! -e ${lib.escapeShellArg keyFile} ]]; then
          run mkdir -p ${lib.escapeShellArg (dirOf keyFile)}
          run ${pkgs.openssh}/bin/ssh-keygen -q -t ed25519 -N "" \
            -C "agent-push@${hostKey}" -f ${lib.escapeShellArg keyFile}
        fi
      '';
    }

    (lib.mkIf (host ? agentPushKey) {
      home.packages = [ push ];

      systemd.user = {
        services.agent-session-push = {
          Unit.Description = "Push agent session files to the archive on mini";
          Service = {
            Type = "oneshot";
            ExecStart = lib.getExe push;
            Nice = 10;
            IOSchedulingClass = "idle";
          };
        };

        timers.agent-session-push = {
          Unit.Description = "Push agent session files to mini every 15 minutes";
          Timer = {
            OnCalendar = "*:0/15";
            RandomizedDelaySec = "2m";
            # Catch up after sleep or power off.
            Persistent = true;
          };
          Install.WantedBy = [ "timers.target" ];
        };
      };
    })
  ]
)
