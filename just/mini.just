# Mini host management — invoked as `just mini <cmd>` from any host that can
# `ssh mini`. Service ops live in the nested `llm` module (`just mini llm <cmd>`).
# Commit + push your flake changes first; deploy/pull pull origin/main on mini and
# build there. Override the target off-LAN with MINI_SSH=mini.quokka-qilin.ts.net.
set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

mod llm "mini-llm.just"

mini_ssh := env('MINI_SSH', 'mini')

[doc('git pull --ff-only the flake on mini (no build)')]
pull:
    ssh {{mini_ssh}} 'bash -lc "git -C ~/.dotfiles/flake pull --ff-only"'

[doc('Pull newest flake on mini, then nh switch')]
deploy:
    ssh -t {{mini_ssh}} 'bash -lc "set -e; cd ~/.dotfiles/flake && git pull --ff-only && just switch-fast"'

[doc('Pull newest flake on mini, then build-dry (no activation)')]
deploy-dry:
    ssh -t {{mini_ssh}} 'bash -lc "set -e; cd ~/.dotfiles/flake && git pull --ff-only && just build-dry"'

[doc('Pull newest flake on mini, stage for next reboot')]
deploy-boot:
    ssh -t {{mini_ssh}} 'bash -lc "set -e; cd ~/.dotfiles/flake && git pull --ff-only && just build-boot"'

[doc('Open an interactive ssh shell on mini')]
ssh:
    ssh -t {{mini_ssh}}

[doc('Reboot mini (e.g. after deploy-boot)')]
reboot:
    ssh {{mini_ssh}} 'bash -lc "sudo systemctl reboot"'

[doc('Reconcile Cloudflare DNS A records with the mini Caddy vhosts (create if missing). Runs locally.')]
dns-sync:
    bash "$FLAKE/scripts/shell/dns-sync.bash"

# Safe gateway restart: NEVER use the dashboard's "restart gateway/connection"
# action — it spawns a gateway inside the dashboard's cgroup, grabs gateway.lock,
# and crash-loops the real hermes-agent.service. Restart the unit directly instead.
[doc('Restart the hermes gateway (hermes-agent.service) on mini — safe alternative to the dashboard restart button')]
hermes-restart:
    ssh {{mini_ssh}} 'bash -lc "sudo systemctl restart hermes-agent.service"'
    @echo "hermes-agent restarted on mini"

[doc('Restart the hermes dashboard on mini — refreshes its stale connection/"configured" view after .env secret changes')]
hermes-dashboard-restart:
    ssh {{mini_ssh}} 'bash -lc "sudo systemctl restart hermes-dashboard.service"'
    @echo "hermes-dashboard restarted on mini"

[doc('Show hermes-agent + hermes-dashboard service status on mini')]
hermes-status:
    ssh {{mini_ssh}} 'bash -lc "systemctl status hermes-agent.service hermes-dashboard.service --no-pager -n 5 || true"'

[doc('Follow hermes-agent logs on mini')]
hermes-logs:
    ssh -t {{mini_ssh}} 'bash -lc "journalctl -u hermes-agent.service -f -n 100"'


# Media stack maintenance (VPN / downloaders / *arr / playback).
# vpn-restart force-kills SABnzbd if stop hangs and bypasses nixflix wg-up's ICMP
# gate (Proton peers often drop ping). Needs a healthy Proton WG peer in sops.

[doc('Media stack status: VPN handshake, downloaders, arr, plex/jellyfin')]
media-status:
    bash "$FLAKE/scripts/shell/mini-media.bash" --remote status

[doc('WireGuard / netns egress check on mini')]
vpn-status:
    bash "$FLAKE/scripts/shell/mini-media.bash" --remote vpn-status

[doc('Restart VPN netns (UDP gate) + qBittorrent/SABnzbd — use when Search/downloads stall')]
vpn-restart:
    bash "$FLAKE/scripts/shell/mini-media.bash" --remote vpn-restart

[doc('Restart qBittorrent + SABnzbd only (requires wg already up)')]
downloaders-restart:
    bash "$FLAKE/scripts/shell/mini-media.bash" --remote downloaders-restart

[doc('Restart Sonarr/Radarr/Lidarr/Prowlarr/FlareSolverr')]
arr-restart:
    bash "$FLAKE/scripts/shell/mini-media.bash" --remote arr-restart

[doc('Restart Plex/Jellyfin/Bazarr/Seerr')]
media-restart:
    bash "$FLAKE/scripts/shell/mini-media.bash" --remote media-restart

[doc('Full bounce: vpn+downloaders → arr → media servers')]
stack-restart:
    bash "$FLAKE/scripts/shell/mini-media.bash" --remote stack-restart


# Immich photo library + its off-host restic backup to Unraid.
# Migration runbook: docs/hosts/mini-immich.md. These are the recurring ops.
# The one-time rsync seed steps are deliberately NOT recipes — they carry
# host-specific paths and belong in the runbook, not in `just`.

[doc('Immich status: server, machine learning, postgres, redis')]
immich-status:
    ssh {{mini_ssh}} 'bash -lc "systemctl status immich-server immich-machine-learning postgresql redis-immich --no-pager -n 5 || true"'

[doc('Follow immich-server + immich-machine-learning logs on mini')]
immich-logs:
    ssh -t {{mini_ssh}} 'bash -lc "journalctl -u immich-server -u immich-machine-learning -f -n 100"'

[doc('Restart Immich (server + machine learning) on mini')]
immich-restart:
    ssh {{mini_ssh}} 'bash -lc "sudo systemctl restart immich-server immich-machine-learning"'
    @echo "immich restarted on mini"

[doc('Immich media usage on /srv + Postgres database size')]
immich-du:
    ssh {{mini_ssh}} 'bash -lc "sudo du -sh /srv/immich/* ; sudo -u postgres psql -d immich -tAc \"select pg_size_pretty(pg_database_size(current_database()))\""'

[doc('List Immich users (post-restore sanity check)')]
immich-users:
    ssh {{mini_ssh}} 'bash -lc "sudo -u immich immich-admin list-users"'

[doc('Vector-search health: vchord/pgvector extensions + CLIP/face index sizes')]
immich-vectors:
    ssh {{mini_ssh}} 'bash -lc "sudo -u postgres psql -d immich -c \"select extname, extversion from pg_extension order by 1\" -c \"\\di+ clip_index\" -c \"\\di+ face_index\""'

[doc('Interactive immich-admin change-media-location (stops immich-server for the duration)')]
immich-media-location:
    ssh -t {{mini_ssh}} 'bash -lc "sudo systemctl stop immich-server; sudo -u immich immich-admin change-media-location; sudo systemctl start immich-server"'

[doc('Immich backup status: timers, last result, newest snapshots, repo size')]
immich-backup-status:
    ssh {{mini_ssh}} 'bash -lc "systemctl list-timers restic-backups-immich.timer restic-backups-immich-maint.timer immich-backup-watchdog.timer --no-pager; systemctl status restic-backups-immich immich-backup-watchdog --no-pager -n 3 || true; sudo restic-immich snapshots --latest 3 --tag immich; sudo restic-immich stats --mode raw-data"'

[doc('Run the Immich backup now (pg_dump + snapshot) and follow the journal')]
immich-backup-now:
    ssh -t {{mini_ssh}} 'bash -lc "sudo systemctl start --no-block restic-backups-immich.service && journalctl -u restic-backups-immich.service -f -n 50"'

[doc('List Immich restic snapshots')]
immich-backup-snapshots:
    ssh {{mini_ssh}} 'bash -lc "sudo restic-immich snapshots --tag immich"'

[doc('Run monthly maintenance now: forget --prune + check --read-data-subset=5%')]
immich-backup-check:
    ssh -t {{mini_ssh}} 'bash -lc "sudo systemctl start --no-block restic-backups-immich-maint.service && journalctl -u restic-backups-immich-maint.service -f -n 50"'

[doc('Restore drill: verify the newest DB dump + byte-compare 20 random originals')]
immich-backup-drill:
    bash "$FLAKE/scripts/shell/mini-immich-drill.bash" --remote

[doc('Mount the newest Immich backup snapshot at /mnt/immich-backup on mini (FUSE)')]
immich-backup-mount:
    ssh -t {{mini_ssh}} 'bash -lc "sudo mkdir -p /mnt/immich-backup && sudo restic-immich mount /mnt/immich-backup"'

[doc('Clear a stale restic lock (only after confirming no backup is running)')]
immich-backup-unlock:
    ssh {{mini_ssh}} 'bash -lc "sudo restic-immich unlock"'
