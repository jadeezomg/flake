# Unraid (jadee-server) — invoked as `just unraid <cmd>`.
# Override off-LAN: UNRAID_SSH=root@jadee-server.tailnet.example just unraid flash-diagnose
set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

unraid_ssh := env('UNRAID_SSH', 'root@jadee-server')

[doc('Diagnose USB flash (/boot) write activity on Unraid (~35s idle watch)')]
flash-diagnose:
    bash "$FLAKE/scripts/shell/unraid-flash-diagnose.bash" --remote

[doc('Open an interactive ssh shell on Unraid')]
ssh:
    ssh -t {{unraid_ssh}}
