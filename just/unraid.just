# Unraid (jadee-server) — invoked as `just unraid <cmd>`.
# Override off-LAN: UNRAID_SSH=root@jadee-server.tailnet.example just unraid ssh
set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

unraid_ssh := env('UNRAID_SSH', 'root@jadee-server')

[doc('Open an interactive ssh shell on Unraid')]
ssh:
    ssh -t {{unraid_ssh}}

# The plugin files live on the flash drive; fancurve.plg copies them into RAM
# at each boot. "forced" lets the same version install again.
[doc('Install or update the fancurve fan plugin on Unraid')]
fancurve-deploy:
    ssh {{unraid_ssh}} 'mkdir -p /boot/config/plugins/fancurve/src'
    rsync -rc --delete "$FLAKE/scripts/unraid/fancurve/src/" {{unraid_ssh}}:/boot/config/plugins/fancurve/src/
    scp "$FLAKE/scripts/unraid/fancurve/fancurve.plg" {{unraid_ssh}}:/tmp/fancurve.plg
    ssh {{unraid_ssh}} 'plugin install /tmp/fancurve.plg forced'

[doc('Show fancurve state, temperatures, and fan channels on Unraid')]
fancurve-status:
    ssh {{unraid_ssh}} /usr/local/emhttp/plugins/fancurve/scripts/fancurve status
