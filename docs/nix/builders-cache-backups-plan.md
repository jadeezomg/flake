# Plan: Linux remote builders, Cachix warm, store hygiene, backups

**Status:** proposed  
**Related:** [mini.md § Known gaps](../hosts/mini.md), [hosts/mini/flake-cache-warm.nix](../../hosts/mini/flake-cache-warm.nix), [per-host-and-pass-plan.md](../secrets/per-host-and-pass-plan.md), Mic92 `nixosModules/{builder,remote-builder}.nix`.

---

## Why caya is out of the remote-build path

**Correct: do not wire caya as a remote-build client or builder for day-to-day switches.**

| Fact | Consequence |
|---|---|
| `caya` is `aarch64-darwin` | Only a Darwin machine can build those store paths |
| mini / desktop are `x86_64-linux` | They cannot produce Darwin closures |
| No second Mac / Darwin build farm | Nowhere to offload `darwin-rebuild` / `nix build .#darwinConfigurations.caya` |

So:

- **Remote `buildMachines`:** Linux hosts only (framework → mini/desktop; optionally desktop → mini).
- **Cachix warm on mini:** keep building **only** the three NixOS tops (`mini`, `desktop`, `framework`) — already what [`flake-cache-warm.nix`](../../hosts/mini/flake-cache-warm.nix) does. Do **not** add caya to that job.
- **caya still benefits from substituters** for any *cached* paths that happen to match (nixpkgs fixed-output, some pure deps) — leave `jadee-flake.cachix.org` in shared nix settings — but expect most Darwin-native paths to build locally on caya.
- **Optional later (not this plan):** after a successful caya switch, push *that Mac’s* closure to Cachix from caya itself so a second Mac (or reinstall) can pull. That is “Darwin self-push,” not remote build.

Cross-compile / Linux-from-Mac (`pkgsCross`, container images) is rare here; ignore unless a concrete need appears.

---

## Goals

1. Offload heavy NixOS builds from **framework** (and optionally desktop) to always-on / stronger Linux boxes via `ssh-ng`.
2. Turn on the already-written **mini → Cachix** nightly warm so Linux switches mostly substitute.
3. Tighten **store GC** without nuking active direnv shells.
4. Close the **backup gap** (borg or restic → mini), without Clan.

Non-goals: Harmonia, clan SSH CA / WG mesh, Darwin remote builders, iroh-ssh, `mitigations=off`.

---

## Target topology

```text
                    ┌─────────────┐
                    │ jadee-flake │
                    │   Cachix    │
                    └──────▲──────┘
                           │ push (nightly)
                    ┌──────┴──────┐
     buildMachines  │    mini     │  builder user `nix`
     ssh-ng ────────┤  (server)   │  cache-warm timer
                    └──────▲──────┘
                           │ optional
┌──────────┐        ┌──────┴──────┐
│framework │───────►│   desktop   │  builder user `nix`
│ (client) │ ssh-ng │ (builder +  │  strong CPU
└──────────┘        │  optional   │
                    │  client)    │
                    └─────────────┘

caya (Darwin): local builds only; may pull Cachix hits; no buildMachines entry
```

| Host | Builder? | Remote-build client? | Cachix |
|---|---|---|---|
| **mini** | yes (`x86_64-linux`) | no (builds locally; weak `buildCores = 2` — prefer not to *receive* huge jobs if desktop is up) | push (warm) + pull |
| **desktop** | yes (`maxJobs` high, `buildCores = 24`) | optional → mini for idle/overnight | pull (+ optional push later) |
| **framework** | no | yes → desktop primary, mini fallback | pull |
| **caya** | n/a (self only) | **no** | pull only |

Prefer **desktop as primary builder** (cores); **mini as fallback / always-on** when desktop is asleep. Framework should set `max-jobs` locally low and rely on remotes for `big-parallel`.

---

## Architecture (Mic92-shaped, flake-native)

Steal the two-module split:

1. **Builder host module** — system user `nix`, group, `nix.settings.trusted-users`, SSH authorized key(s) for the builder identity.
2. **Client module** — `nix.distributedBuilds = true`, `nix.buildMachines = [ … ]`, sops SSH private key, `programs.ssh.extraConfig` with `ServerAliveInterval` / `ServerAliveCountMax` so dead Tailscale links don’t wedge `build-remote`.

Builder SSH key: one ed25519 in **shared or per-client host sops** (fits per-host secrets plan: e.g. `shared.yaml` path `nix/remote-builder` if every Linux client shares it, or per-host copies). Public half in builder modules’ `authorizedKeys`.

Reach builders over **Tailscale** hostnames already in [`data/network/ssh-destinations.nix`](../../data/network/ssh-destinations.nix) — no new VPN.

Also bump today’s global [`max-jobs = 1`](../../modules/shared/environment.nix) on builder hosts (and reconsider the global default: clients can stay low; builders need `max-jobs` ≫ 1).

---

## Phases

### Phase 0 — Inventory & decisions (no deploy)

1. Confirm Tailscale SSH to `mini` / `desktop` as user that can become `nix@` (or dedicated key only).
2. Pick primary builder: **desktop**, fallback **mini**.
3. Note mini `buildCores = 2` — cap `maxJobs` on mini’s `buildMachines` entry (e.g. 2–4) so framework doesn’t melt the server; desktop entry `maxJobs` ≈ 8–16 (tune to heat/noise).
4. List secrets to add (align with pass-inventory / SCHEMA when secrets split lands):
   - `nix/remote-builder` (private key) — clients
   - existing `cachix/auth-token`, `mini/git/deploy-key` — warm pipeline

### Phase 1 — Enable Cachix warm on mini (independent, high ROI)

Already documented in mini.md; code exists but **not imported**.

1. `cachix create jadee-flake` (if missing); put real pubkey in `modules/shared/environment.nix` (uncomment substituter).
2. Push token → sops `cachix/auth-token`; deploy key → `mini/git/deploy-key`.
3. Import `./flake-cache-warm.nix` from `hosts/mini/default.nix`.
4. Manual `systemctl start flake-cache-warm.service`; verify push; `nix store ping --store https://jadee-flake.cachix.org` from framework.
5. Keep build list = three NixOS configs only (no caya).

### Phase 2 — Builder accounts + client wiring

1. Add `modules/nixos/nix-builder.nix` (Mic92 `builder.nix` analogue): user `nix`, trusted, empty home, authorized key from `data/` or option.
2. Enable on **desktop** and **mini** via host imports / profile `dotfiles.profiles.server.nixBuilder` (or host-local import).
3. Add `modules/nixos/nix-remote-builds.nix` (client): options for machine list; default framework → desktop + mini; SSH key from sops; keepalive stanza.
4. Enable on **framework** only (and optionally desktop → mini).
5. **Do not** import remote-builds on **caya** / nix-darwin.
6. Smoke test from framework:

   ```bash
   nix build -L --builders 'ssh-ng://nix@desktop …' nixpkgs#hello
   nix build -L .#nixosConfigurations.framework.config.system.build.toplevel
   ```

7. Just helpers (optional): `just builders-status`, `just builders-test`.

### Phase 3 — Store hygiene

1. Add `fast-nix-gc` flake input (or vendor the two scripts) on Linux workstations + mini; wire weekly timer beside existing [`modules/nixos/gc.nix`](../../modules/nixos/gc.nix).
2. Set `nix.settings.keep-outputs = true` and `keep-derivations = true` on workstations (framework/desktop) so nix-direnv GC survival matches Mic92.
3. Revisit global `max-jobs = 1`: builders override high; framework client low local + remotes; mini local modest.

### Phase 4 — Backups → mini

1. Choose **borg** (Mic92-shaped) or **restic** (simpler S3-ish later). Default this plan: **borg** over Tailscale to mini.
2. mini: borg repo disk path (dedicated disk/subvol), `borgbackup` serve or SSH user `backup` with append-only key.
3. framework + desktop: `services.borgbackup.jobs.home` (or nixos module wrappers) with sane excludes (`.cache`, `result`, Steam, Containers).
4. Secrets: repo passphrase / SSH key in host sops; Pass inventory mirror optional for human recovery passphrase only.
5. Document restore drill in `docs/hosts/mini.md`; add `just backup-status`.
6. caya: separate later (Time Machine / restic to mini is fine as a follow-up; not blocked by Linux builders).

### Phase 5 — Polish (optional)

1. Framework: zswap / suspend-on-low-battery if still desired.
2. Client **prefetch**: idle timer that `nix build` roots next generation from Cachix (Mic92 `update-prefetch` idea) — only after Phase 1 is reliable.
3. Darwin self-push from caya to Cachix (separate mini doc section) — only if reinstall pain justifies it.

---

## Module / file sketch

```text
modules/nixos/nix-builder.nix          # builder user on mini + desktop
modules/nixos/nix-remote-builds.nix    # clients: framework (+ optional desktop)
modules/nixos/gc.nix                   # extend with fast-nix-gc / keep-*
hosts/mini/default.nix                 # import flake-cache-warm.nix
hosts/mini/services/borg-repo.nix      # Phase 4
hosts/framework/…                      # enable remote-builds
hosts/desktop/…                        # enable builder (+ optional client)
data/network/ssh-destinations.nix      # ensure mini/desktop builder aliases
secrets/…                              # remote-builder key, backup keys
docs/nix/builders.md                   # operator runbook (after implement)
```

Darwin: no new modules for remote builds.

---

## Secrets touchpoints

| Secret | Where | Used by |
|---|---|---|
| `nix/remote-builder` | shared or each Linux client host file | framework (desktop) SSH identity to `nix@` |
| `cachix/auth-token` | mini (or shared) | flake-cache-warm |
| `mini/git/deploy-key` | mini | flake-cache-warm git push |
| `backup/…` | per client + mini | borg (Phase 4) |

Align names with SCHEMA + pass-inventory when the secrets split lands; builder private key is class A/B machine — not Pass session-env.

---

## Risks

- **mini overload:** low `maxJobs` + prefer desktop; don’t let cache-warm and remote builds fight (nice CPUWeight / IOScheduling on the timer).
- **Trusted user `nix`:** only the builder pubkey; no password login; Tailscale ACL if you tighten later.
- **Partial Cachix coverage:** Darwin still local; Linux hits depend on warm success — watch the timer.
- **Secret split ordering:** can implement Phase 1–2 on today’s single `secrets.yaml`, then move keys in the per-host migration.

---

## Success criteria

- [ ] framework can build `hello` and a NixOS toplevel using `ssh-ng` to desktop (and to mini when desktop is down).
- [ ] caya has **no** `nix.buildMachines` / distributedBuilds wiring; Darwin switches remain local.
- [ ] mini cache-warm timer green; framework substitutes from `jadee-flake` on switch.
- [ ] `keep-outputs` / faster GC in place on Linux workstations.
- [ ] borg job from framework → mini completes; restore drill documented once.

---

## Suggested implementation order

1. **Phase 1** — Cachix warm (unblocks everyone Linux immediately).  
2. **Phase 2** — builders (framework quality-of-life).  
3. **Phase 3** — GC hygiene.  
4. **Phase 4** — backups.  
5. **Phase 5** — polish / optional Darwin self-push.

Secrets per-host work can proceed in parallel; only share secret *names* with this plan.
