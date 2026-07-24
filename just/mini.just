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
