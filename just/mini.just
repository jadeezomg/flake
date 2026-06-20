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
