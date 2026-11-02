# Mini — operations & troubleshooting

Reference for the `mini` host machine (Minisforum MS-01, headless NixOS).

**Scope:** only what is *not* readable from the flake. Every "what is configured"
question is answered by `hosts/mini/**`, `mini-nix` and the module tree; this file records the
ordering constraints, failure modes, one-time runtime steps and deliberate
decisions that the Nix code cannot express. When the two disagree, the flake wins
— fix this file.

**Service modules are private.** `hosts/mini/**` keeps only the host facts,
profiles, hardware/disko and base system. Every service (media, LLM, agents,
Hermes, Matrix, Immich, Homepage, …) and their wiring now live in the private
`mini-nix` repo, imported as the `mini-nix` flake input. Paths written as
`mini-nix/services/...` below are relative to that repo; its secrets and schema
are in `mini-nix/secrets/`.

---

## 1. Hardware & storage facts

| | |
|---|---|
| CPU / RAM | i5-12600H (4P+8E, vPro), 24 GB |
| GPU | discrete Intel Arc B50 (~15 GiB) + iGPU; needs `xe.force_probe=e223` |
| Disks | 256 GB NVMe (ESP + btrfs `@root @nix @home @var-log @snapshots`), 2 TB NVMe (btrfs → `/srv`) |
| NICs | 4 present, only `enp2s0f0np0` configured (`192.168.178.100/24`, gw `.1`) |
| OOB | Intel AMT 16.x, Client Control Mode |

Non-obvious:

- **`/tmp` is not tmpfs** (`boot.tmp.useTmpfs = false`, no `cleanOnBoot`). It is a
  plain directory on the btrfs root and **survives reboots**. Because btrfs is
  copy-on-write, `shred` there cannot reliably overwrite the original extent — put
  transient key material in **`/dev/shm`**. The only swap is zram (RAM), so nothing
  written to `/dev/shm` reaches disk. If a secret ever lands on `/tmp`, do not
  scrub it — rotate it.
- **No disk swap**, zram only (50%).
- `/nix` lives on the small 256 GB SSD → GC is deliberately aggressive
  (`daily`, `--delete-older-than 3d`).
- `buildCores = 2` — 24 GB is not much for a rebuild that also serves a 10 GB model.
- The 2 TB disk holds `/srv` only: `/srv/immich` (photo library) and
  `/srv/nixflix` (media service state). Media *payloads* are NFS from Unraid, not here.

## 2. Boot & SecureBoot

`secureBoot = false` today; lanzaboote is wired but inert.

**Enrollment order matters — two ways to break the box:**

1. `sudo sbctl create-keys` (creates `/var/lib/sbctl`)
2. flip `secureBoot = true` in `hosts/mini/host.nix`, commit
3. `just switch` → lanzaboote writes **signed** EFI files
4. `sudo sbctl verify` → every ESP entry must say signed
5. firmware → Security → *Reset to Setup Mode* / *Clear PK*
6. `sudo sbctl enroll-keys -m`
7. reboot, enable SecureBoot in firmware, `sudo sbctl status`

- Enabling lanzaboote **before** sbctl keys exist fails the switch (no PKI bundle).
- Enrolling keys **before** signed binaries are on the ESP makes the next boot fail.
- Without Setup Mode, `enroll-keys` fails or silently no-ops.
- **`-m` is not optional** — it imports Microsoft's KEK+DB; skip it and fwupd
  capsule updates are bricked.
- Recovery: clear all SecureBoot keys in firmware (back to Setup Mode), redo.

**`fwupd-refresh` makes `switch` return 4.** It races a restarting `fwupd.service`
/ LVFS and exits 1 (nixpkgs#288598, open). `hosts/mini/default.nix` forces
`SuccessExitStatus = [1 2]` behind an expiry guard (rechecks at fwupd ≥ 2.3). Run
`fwupdmgr refresh && fwupdmgr update` by hand when you actually want metadata.

Kernel is `cachyos-server` (not zen4) and Plymouth is off — both gated on
`server.enable`.

## 3. Network, DNS, firewall

- The firewall **trusts only `tailscale0`**; the sole public port is `:22`.
  Everything else (`:8000` llama.cpp, `:8080` open-webui, Caddy) is tailnet-only.
- **AMT ports `16992-16995` sit below the OS firewall** — `networking.firewall`
  cannot gate them; only AMT's own ACL does. AMT shares the NIC MAC with the OS.
  It is **LAN-only** — Tailscale cannot reach it (AMT is below the OS network
  stack). AMT-over-VPN would need a subnet router elsewhere; not done.
- Tailscale requires one interactive login once: `sudo tailscale up --ssh`.
- **Legacy `tailscale serve` mappings linger in `tailscaled` state** after the move
  to Caddy and keep answering on `mini.quokka-qilin.ts.net`. Clear once:
  `sudo tailscale serve reset` (then `tailscale serve status` → empty).

`environment.enableAllTerminfo` is on so `TERM=xterm-kitty` forwarded over SSH does
not break pagers/`systemctl`. On a pre-that generation use `kitty +kitten ssh`.

## 4. Secrets

Canonical paths: `secrets/SCHEMA.md` and, for mini's services,
`mini-nix/secrets/SCHEMA.md`. Two different age keys live on mini:

| Key | Path | Used by |
|---|---|---|
| **host** key | `/var/lib/private/sops/age/keys.txt` | NixOS `sops.secrets` |
| **editor** key | `~/.config/sops/age/keys.txt` | Home Manager `sops-nix.service` |

**The host key alone is not enough** — HM decrypts user secrets with the same
editor key as your workstation, so it must be copied to mini (dir `0700`, file
`0600`) or `just switch` fails on the HM side. `just bootstrap-sops-host-key`
handles the host half; `just verify-sops-host-key mini` checks it.

Mini must be a recipient in both `.sops.yaml` files: `&mini` in the dotfiles
repo and in `mini-nix`, with `- *mini` under `creation_rules`, then
`sops updatekeys secrets/secrets.yaml` in each repo you changed.

The AMT/MEBx password belongs in the mini-nix sops file as `mini/amt/password`.
It is not stored there yet. You set the password in MEBx (§8, step 1).

## 5. Deploy & ops

```bash
mini ship "msg"    # commit+push mini-nix, re-pin the input, deploy
mini bump          # re-pin flake.lock to mini-nix main, push
mini deploy        # git pull --ff-only on mini + nh switch (switch-fast)
mini deploy-dry    # build only, no activation
mini deploy-boot   # stage for next reboot (kernel/bootloader)
mini status        # state of every service by group, then all failed units
mini pull / ssh / reboot / dns-sync
mini llm <cmd>     # LLM service ops (nested module)
```

- **`deploy` pulls `origin/main`** — commit *and push* first, or you deploy the old tree.
- **`mini-nix` is pinned to a commit in `flake.lock`.** A plain `deploy` never
  picks up new mini-nix commits: push mini-nix, then `mini bump` (or let
  `mini ship "msg"` do commit + push + bump + deploy). The deploy recipes
  print a note when `flake.lock` is behind mini-nix `main`.
- **The `mini-nix` input is private.** The build on mini fetches it over SSH
  with `jadee`'s own key, which has read access; no separate deploy key is
  configured. Without access the eval fails at input fetch, before any module
  is read.
- `mini secret-set mini/...` writes `mini-nix/secrets/secrets.yaml`;
  `just secret-set` still writes this repo's shared secrets file.
- `deploy` uses `switch-fast` (no flake check, no commit on mini) since you authored
  upstream. Run `deploy-dry` first when you want a pre-flight build.
- **Author changes locally, never over SSH on mini.** Remote is inspect/deploy only.
- `flake fmt` after `.nix` edits, `git add -A` before any eval — flakes only see
  tracked files.
- **Mini's login shell is nushell** — for one-liners use `ssh mini 'bash -lc "…"'`.
- **`mini` is the CLI for these recipes.** It runs the `Justfile` in the private
  mini-nix checkout (`~/git/mini-nix`), which owns the
  host ops, the secrets recipes and the LLM ops (`mini llm <cmd>`). The flake
  installs a thin `mini` wrapper (`modules/profiles/minimal/shells/mini-cli.nix`).
  List with `mini --list`, `mini --list llm`. Recipes that run flake scripts
  read `DOTFILES_DIR` (default `~/git/flake`). `MINI_NIX_DIR` changes only the
  checkout that `ship` and `bump` use.
- Host is reached **by address, not name** (`sshAddress = 192.168.178.100`) because
  it is headless and ops must work before name resolution does. Off-LAN:
  `MINI_SSH=mini.quokka-qilin.ts.net`.

## 6. Services

The service notes are in the private mini-nix repo, in `docs/services.md`. They
cover the LLM stack, Immich, the media stack, Matrix, Hermes, Caddy, Atuin,
Homepage, the agent session archive, and the service gaps. The service
decisions (ADR-0003 to ADR-0007) and the LLM benchmarks are in `docs/adr/` and
`docs/bench/` of the same repo.

## 7. Known gaps / deferred

- **Power tuning** — stock. Candidates: `powersave` governor, `thermald`, ASPM in
  BIOS, `logind.lidSwitch = "ignore"`. No `tlp` (laptop-oriented, conflicts with
  thermald). Wake-on-LAN pointless (always on).
- **AMT-over-VPN** — needs a Tailscale subnet router on another always-on host.
- Verify Stylix/DMS/Niri stay inert with `desktop.enable = false` during a
  `just build-dry`; gate their imports on headless if any leak.

## 8. Rebuilding from scratch

Full procedure lives in git history (`docs/hosts/mini-install.md` before this
consolidation). The parts that are not obvious:

1. **MEBx (`Ctrl+P` at POST, physical access once):** change the `admin` password,
   DHCP + router reservation, enable SOL/IDER/KVM, **user consent None** (required
   for unattended headless access — accepted tradeoff), activate in **CCM**. Then store
   the password in the mini-nix sops file as `mini/amt/password` (not stored
   yet, see §4). Verify: `curl -k https://<amt-ip>:16993/` and
   `nix shell nixpkgs#amtterm -c amtterm <amt-ip>`.
2. **Installer wifi:** ethernet may not be routed yet. Disable NM scan MAC
   randomization first (`[device] wifi.scan-rand-mac-address=no` in
   `/etc/NetworkManager/conf.d/`) — some APs choke on it. If it sticks at
   "connecting (configuring)", delete the transient profile and re-add with
   `802-11-wireless.cloned-mac-address permanent`, `ipv4.method auto`,
   `ipv6.method disabled`.
3. **disko destroys both NVMes** — re-check `/dev/disk/by-id/nvme-…` for the 256 GB
   *and* the 2 TB disk before running it.
4. **`nixos-install --max-jobs 1 --cores 4`** — it uses the *installer's* daemon, so
   mini's `buildCores` does not apply, and 24 GB will thrash otherwise.
5. **Bootstrap mode is the chicken-and-egg fix and has been removed from
   `host.nix`.** sops-nix cannot decrypt before mini's age host key exists, so
   `users.users.jadee.hashedPasswordFile` cannot be declared on first install.
   Re-introduce a `miniBootstrap` toggle that (a) uses `initialPassword` and (b)
   skips `mini-nix/services/llm`, then flip it off only after the sops checklist in §4 is
   complete. `--no-root-password` is correct — root stays locked, jadee has
   NOPASSWD wheel.
6. **Password SSH is disabled from first boot** — your key must already be in
   `data/users/users.nix` → `jadee.sshKeys` and committed *before* `nixos-install`.
   Recovery is console or AMT KVM only.
7. The installer's `/tmp/flake` clone is gone after reboot — clone to
   `~/git/flake` and run `just _init mini` before any `just` recipe.
8. SecureBoot enrollment last (§2), after the host is reachable.

Smoke test: key-only SSH from desktop and over Tailscale, `sudo whoami` without a
prompt, `sbctl status`, `amtterm`, `https://<amt-ip>:16993`, then each service's
`mini …-status`.
