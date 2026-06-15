# Task 1 — Deploy + verify beszel GPU monitoring

**State:** code complete, **staged but uncommitted** in `hosts/mini/services/beszel.nix` (`git status` shows it modified vs HEAD). Not yet deployed.

## What was done
`intel_gpu_top` cannot read the B50 — Battlemage uses the `xe` driver, which lacks the i915 PMU (`Failed to detect engines! … Kernel 4.16 required for i915 PMU`). Verified **nvtop reads the B50** (`nix shell nixpkgs#nvtopPackages.intel -c nvtop -s` → JSON with `gpu_util`, `power_draw`, processes). So `beszel.nix` now:
- `services.beszel.agent.extraPath = [pkgs.nvtopPackages.intel];`
- `environment.GPU_COLLECTOR = "nvtop";` (auto-detect would pick the broken intel_gpu_top)
- `systemd.services.beszel-agent.serviceConfig.SupplementaryGroups = lib.mkForce ["podman" "disk" "video" "render"];` — agent was only in `podman disk`; needs `video` to open `/dev/dri/card0` (root:video 0660).

## Steps
1. `git add -A && git commit && git push` (from this repo), then **`just mini deploy`**.
2. Verify the agent picked nvtop, not the failing collector:
   `ssh mini 'bash -lc "journalctl -u beszel-agent -n 30 --no-pager"'`
3. Open `https://mini.quokka-qilin.ts.net:8090` — the `mini` system should show GPU load/power; the B50 (and Iris Xe) appear.

## Gotchas
- On the `xe` driver, nvtop returns some fields null/bogus (temp came back `255C` sentinel, memory totals null). Utilization/power/processes work; a full sensor panel does not — xe/nvtop limitation, not fixable here.
- Beszel onboarding is already done; admin is `admin@jadee.fyi`, password in `/root/beszel-admin.txt` on mini (recommend resetting in UI). System `mini` is registered (SSH path, 127.0.0.1:45876).

## Suggested skills
- `verify` — confirm the change works in the live dashboard.
