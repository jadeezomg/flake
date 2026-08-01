# Network facts for machines this flake TALKS TO but does not MANAGE.
#
# Flake-managed hosts (desktop, framework, caya, mini) keep their own facts in
# `hosts/<name>/host.nix` — that is the single source of truth for them, and
# nothing here should duplicate it. This file exists for the boxes that have no
# `host.nix` because the flake does not build them, yet whose addresses several
# modules need: without it the same literal IP gets pasted into NFS mounts,
# backup transports, ssh aliases and ops scripts, and they drift apart the day
# the LAN gets renumbered.
#
# Exposed as `dotfilesLib.lanHosts` (lib/default.nix), so consumers reach it
# through the named channel instead of climbing with `../../`.
#
# Consumers:
#   hosts/mini/services/media/storage.nix     NFS mounts (/data, /Music, /media)
#   hosts/mini/services/immich-backup.nix     restic sftp transport
#   data/network/ssh-destinations.nix         the `unraid` ssh alias
{
  hosts = {
    # Unraid NAS. Runs the household share pool and, since ADR-0007, receives
    # mini's Immich backup. Tailscale SSH is available on the tailnet name but
    # periodically demands an interactive browser re-auth, so automation should
    # prefer `lan`.
    unraid = {
      lan = "192.168.178.62";
      tailnet = "jadee-server"; # MagicDNS; also the LAN hostname
      sshUser = "root";
      # Unraid user-share root. Individual exports hang off this
      # (/mnt/user/data, /mnt/user/Music, /mnt/user/backup, ...).
      shareRoot = "/mnt/user";
    };
  };
}
