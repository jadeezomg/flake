---
name: flake-update
description: Update this flake's inputs and local packages, and fix a build that breaks after an update. Use it to run `just update`, `just update-packages`, `just nix-update-pkg`, or `nix flake update` for all or one input. Also use it to fix a build or evaluation that broke after a `flake.lock` or package bump.
---

# Flake update

## Scope

This skill covers the update recipes in `Justfile`, the `update-packages` script (`scripts/src/flake_scripts/update_packages.py`), `flake.lock`, and the fixes after a bump. For overlays and expiry guards, use `overlays`. For package layout and `update.json` fields, use `flake-structure` and `packages/AGENTS.md`.

If the user asks for an update, you can run the update recipes. Do not run `just build*`, `just switch`, or a full system evaluation. Ask the user to run `just build` and send you the output.

## What `just update` does

The recipe runs these steps in order, with `set -euo pipefail`:

| Step | Effect |
| --- | --- |
| 1. `update-packages` | `uv run --project scripts update-packages` updates every `packages/<name>/` that has an `update.json`, in parallel. `UPDATE_FORCE=1` adds `--force`. |
| 2. `nix flake update` | Moves every input that has no rev or tag in its URL. |
| 3. `just fmt` | Runs `treefmt`, the same as `flake fmt`. |
| 4. `fwupdmgr` | Looks for firmware updates, on framework only. |

If one package fails in step 1, the script exits with 1 and the recipe stops before step 2.

Other entry points:

- `just update-packages [--force] [PACKAGE...]` runs step 1 alone. It does not format.
- `just nix-update-pkg <attr> [nix-update flags]` runs `nix-update --flake` on one package attribute, then `just fmt`. It reads no `update.json`, so it ignores the cooldown and the `hold`. Always pass `<attr>`, because without it the recipe opens an interactive picker.
- `nix flake update <input>...` bumps only the named inputs.

## How `update-packages` decides

- Handler `type` in `update.json`: `nix-update`, `binary_channel`, `fetchzip`, or `npm` (`_HANDLERS`).
- Cooldown: each finished lookup writes `packages/<name>/.update-check.json` (`checked_at`, gitignored). A package that the script looked up in the last hour is skipped and shows `cooldown (1h)`. `--force` ignores the cooldown.
- `hold`: `{"reason": …, "bad_versions": […], "issue": <GitHub issue URL, optional>}`. If upstream is at a bad version, the script keeps `default.nix` at the old version and shows `held at <old>`.
- The first upstream release outside `bad_versions` retires the hold. The run applies the update and prints `packages/<name>/update.json: the hold is obsolete.` with the issue state. Then remove the hold.
- If `default.nix` is already at a version in `bad_versions`, validation fails.

## Steps

1. Read `git status` first. Other sessions can work in the same checkout. Stage and touch only your own files.
2. Run the update that the user asked for.
3. Read `git diff --stat flake.lock packages/`. List the moved inputs and package versions. Compare them with "Known hazards".
4. If you edit a `.nix` file, run `flake fmt`. If you add a file, run `git add` before any eval, because flakes only see tracked files.
5. Ask the user to run `just build` and send the output. A lock bump changes every host, so name the other hosts that the user must build (desktop, framework, caya, mini).
6. Read the warnings and errors in the output. Choose one fix per failure from the table below, then ask for a new build.

## Choose a fix after a bump

| Break | Fix | Model |
| --- | --- | --- |
| A nixpkgs package fails to build or test, and upstream will fix it | Overlay with `expireWhen` or `recheckWhen` | `parts/overlays/`, rules in `overlays` |
| The fixed version is already in nixos-unstable-small | `pkgs-small.<pkg>` behind `expireWhen` on `pkgs.<pkg>.version` | `tuios` in `modules/profiles/devenv/agents/default.nix` |
| A local package in `packages/<name>` got a bad release | `hold` in `update.json`, not `--version=skip` (it never expires) | `packages/AGENTS.md` |
| A module option or unit changed | Fix the module. If the fix is a workaround, add a guard | `overlays` § Module-level guards |
| A `permittedInsecurePackages` entry no longer matches | Move the version in `lib/pkgs.nix` | commit `1f04971f` (ventoy) |
| A fixed-output hash mismatch | Set `lib.fakeHash`, ask for a build, paste the `got:` hash | Caddy below |
| A store path must stay fixed | Pin the input to a rev in `flake.nix`, with a comment. No guard | `nixpkgs-skhd` |

## Known hazards

- Immich on mini: `nix flake update` can move Immich to a new major version, which runs irreversible database migrations at the next start. Compare `nix eval --raw --inputs-from . nixpkgs#immich.version` before and after. On a major change, tell the user to read the release notes and run `mini immich-backup-now` before the deploy. Postgres stays pinned to 17. Evidence: `~/git/mini-nix/services/immich.nix` and mini-nix `docs/services.md` § 3.
- skhd on caya: macOS keys the Accessibility grant to the skhd store path. `nixpkgs-skhd` is pinned to a rev, so `nix flake update` does not move it. If you bump that rev, tell the user to grant Accessibility again to the new skhd on caya, or the Vicinae hotkey stops. Evidence: `parts/overlays/skhd-pinned-darwin.nix`, `flake.nix`.
- Homebrew on caya: the `homebrew-cask` and `homebrew-core` inputs move on every update, but `nix-homebrew` pins its own brew. New cask syntax then breaks `brew bundle`. `newerBrew` in `hosts/caya/default.nix` overrides brew until nix-homebrew pins a new enough version. This happened in commits `761151c9` and `66963c58`. Commit `ade6bf53` removed the first override.
- corecycler on desktop: the zenpower and ryzen_smu modules build against the CachyOS kernel and are in no binary cache. Every kernel bump is a local build. Kernel module signing broke them once (`withCertificate`). Evidence: `hosts/desktop/corecycler.nix`, commit `b73cdf94`.
- CachyOS kernel: the `nix-cachyos-kernel` input (`/release`) adds `overlays.pinned` on x86_64-linux. That overlay uses the kernel flake's own nixpkgs, so the kernel comes from `cache.lantian.pub`. The cache changed its URL and key once (commit `38378ee3`). Do not trust the old key again.
- mini-nix input: `nix flake update` also moves `mini-nix` to its `main`. Say so in your report. `mini bump` updates only that input, then commits and pushes `flake.lock`. Run it only on the request of the user. Evidence: `bump` in `~/git/mini-nix/Justfile`.
- Caddy on mini: a Caddy bump in nixpkgs changes the `caddy.withPlugins` hash. Refresh `hash` in `~/git/mini-nix/services/caddy.nix`. Then ask the user to push mini-nix and run `mini bump`. This happened in commits `7bf1340c`, `93eb253b`, and `0cab72ea`.
- Overlay churn: bumps retire overlays and need new ones (commits `c67f3cde`, `dcb1649a`, `a0fa8c75`).

## Expiry warnings after an update

The guards in `lib/expiry.nix` print during evaluation, so they show up in the user's `just build` output:

- `<path> is obsolete: <reason>`: the guard already returns upstream. Remove the workaround (`overlays` § Acting on a warning).
- `<path> needs re-checking: <reason>`: the workaround still applies. Test it by hand, then remove it or move the threshold.
- If the path is not in this repo, it is in mini-nix. Fix it there. Then ask the user to push mini-nix and run `mini bump`.

## Cache before a costly bump

A kernel, compiler, browser, CUDA, or ROCm bump can start a large local build. Before such a bump, make sure that the new output is in a binary cache:

- mcp-nixos: `nix {"action":"cache","query":"<pkg>"}`.
- `nix path-info --store https://cache.nixos.org "$(nix eval --raw <drv>.outPath)"`. For outputs that nixpkgs does not build, use a cache URL from `lib/nix-caches.nix`.

`lib/nix-caches.nix` lists the extra caches. numtide, zed, nix-community, and vicinae also serve Darwin. hyprland, yazi, niri, noctalia, and lantian (the CachyOS kernel) are Linux only.

## Before you hand back

1. `git status` shows no `.update-check.json`, because it is gitignored.
2. Each new workaround has an expiry guard, a `hold`, or a pin comment.
3. Your report lists the moved inputs, the hazards that apply, and the host builds that the user still has to run.
