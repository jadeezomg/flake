# Mini — First-time setup guide

End-to-end install walkthrough for the `mini` host. Companion to
[`mini.md`](./mini.md) (design doc — read first to understand the *why*).

Order matters. AMT first means subsequent steps are remote. SecureBoot
enrollment last because it requires the OS to be installed and reachable.

---

## 0. Prerequisites

- Physical access to the mini at least once (for MEBx provisioning)
- A USB stick (NixOS minimal installer ISO ≥ 25.11) **OR** a working AMT KVM
  redirection setup with the ISO mountable from another host
- Workstation (desktop) with this flake checked out and `sops` working
- The mini connected to LAN with one 2.5G NIC plugged in
- A planned static IP for the mini and the gateway/DNS values

---

## 1. Workstation prep — flake changes

**Status: implemented on branch `add-mini-host`.** The flake compiles
(`nix eval .#nixosConfigurations.mini.config.system.build.toplevel.drvPath`
returns a valid `.drv`). Below is what changed and the inline TODO markers
that **must be filled in** before nixos-install.

### 1.1 What was changed

| File | Change |
|---|---|
| `flake.nix` | new inputs: `disko` (`github:nix-community/disko`), `hermes-agent` (`github:NousResearch/hermes-agent`) — both with `nixpkgs.follows` |
| `parts/hosts.nix` | wired `inputs.disko.nixosModules.disko` and `inputs.hermes-agent.nixosModules.default` into the NixOS module list |
| `modules/nixos/boot.nix` | kernel branches on `server.enable` (cachyos-server vs cachyos-latest-zen4); plymouth gated `lib.mkIf (!server.enable)`; lanzaboote unchanged |
| `modules/nixos/networking.nix` | NixOS `networking.firewall` activated when `server.enable` (drops firewalld/firewalld-gui/proton-vpn/wireguard-ui/networkmanagerapplet from systemPackages on server hosts) |
| `modules/shared/profiles/server.nix` | body emptied — `server.enable` is a steering toggle, gating happens inline in `boot.nix`/`networking.nix` |
| `data/users/users.nix` | added `sshKeys = [ … ]` to `jadee` user (TODO inline; placeholders) |
| `modules/nixos/user.nix` | consumes `userConfig.sshKeys` → `users.users.${user}.openssh.authorizedKeys.keys` |
| `modules/shared/environment.nix` | added `https://jadee-flake.cachix.org` substituter + TODO marker for the trusted public key |
| `home/nixos/default.nix` | gates `./desktop` HM tree on `host ? mainMonitor` — headless hosts skip niri/DMS/dconf-desktop |
| `hosts/hosts.nix` | registered `mini = import ./mini/host.nix` |
| `hosts/mini/*` | full new host: `host.nix`, `profiles.nix`, `default.nix`, `hardware-configuration.nix`, `disko.nix`, `hermes.nix`, `flake-cache-warm.nix` |
| `flake.lock` | locked disko + hermes-agent |

### 1.2 Inline TODO markers that block install

Search `git grep -n TODO` on the branch for the canonical list. As of writing:

| Location | Action before install |
|---|---|
| `data/users/users.nix:23` | paste the actual `ssh-ed25519` public keys from desktop/framework/caya |
| `modules/shared/environment.nix:43` | paste the real `jadee-flake.cachix.org-1:<pubkey>=` (only after running `cachix create jadee-flake` — see §6.1) |
| `hosts/mini/disko.nix:7` | replace `/dev/disk/by-id/nvme-REPLACE_ME` with the real NVMe id from the live ISO (`ls -l /dev/disk/by-id/ \| grep nvme`) |
| `hosts/mini/default.nix:34` (`address1`/`dns`/`interface-name`) | real static IP/gateway/DNS values + verify the 2.5G NIC's predictable name on first boot |
| `hosts/mini/default.nix:8` (`bootstrap`) | leave as `true` for the very first `nixos-install` so jadee gets `initialPassword = "changeme"` (sops decryption would fail before mini's host age key exists); flip to `false` after §5.4 |

### 1.3 Sops state on workstation (pre-install)

`secrets/secrets.yaml` does **not** yet include mini-encrypted secrets — mini's
host age key only exists once the OS is installed (§5.4). Plan now, encrypt
in §5–§7.

Canonical schema lives in [`secrets/SCHEMA.md`](../../secrets/SCHEMA.md).
Mini-relevant entries (quick reference):

| Sops path | When to add |
|---|---|
| `users/jadee/password` | before §5.5 (post-bootstrap switch) |
| `mini/amt/password` | §5.7 (after MEBx is set up) |
| `mini/git/deploy-key` | §6 (cache-warm bootstrap, deferred) |
| `cachix/auth-token` | §6 (cache-warm bootstrap, deferred) |
| `hermes/env` | §7 (hermes first run) |

Re-encrypt with `sops updatekeys secrets/secrets.yaml` after adding mini's
age recipient in §5.4 — schema and command details are in `SCHEMA.md`.

### 1.4 Pre-install verification

```bash
just fmt
nix flake check --no-build
nix eval .#nixosConfigurations.mini.config.system.build.toplevel.drvPath
```

The flake should evaluate clean for `mini` and `desktop`. (As of this branch:
`framework` has a pre-existing upstream `fw-fanctrl` issue unrelated to this
change.)

---

## 2. Pre-install — boot the NixOS installer on mini

Two paths, in order of preference.

### 2.1 Path A — physical USB (first boot, no AMT yet)

Grab the official **minimal** ISO from https://nixos.org/download (pick the
≥25.11 minimal x86_64 image). Don't build from the flake — there's no
ready-made `isoImage` attribute on `nixpkgs` to point a `nix build` at, and
rolling a custom installer adds drift for no benefit here.

> **Reminder — adjust the device path before `dd`.** Run `lsblk` first and
> double-check `/dev/sdX` is the USB stick and not an internal disk.

```bash
# On workstation — replace /dev/sdX with the actual USB device
lsblk
sudo dd if=~/Downloads/nixos-minimal-25.11-x86_64-linux.iso \
        of=/dev/sdX bs=4M status=progress conv=fsync
sync
```

Plug into mini, boot, F11 (boot menu) → USB.

### 2.2 Path B — AMT KVM redirection (after §3)

Once MEBx is provisioned (next section), re-mount the same ISO over IDER from
your workstation. Skip 2.1 if you already have AMT working from a prior box;
otherwise 2.1 first, 2.2 in the future.

---

## 3. MEBx provisioning — vPro / AMT one-time setup

Physical access required this once.

1. Power on mini, hit `Ctrl+P` during POST → MEBx menu
2. Default password: `admin` → forced change. Use a strong password
   (≥8 chars, upper+lower+digit+special). **Save it in your password
   manager AND mirror to sops** as `mini/amt/password` once mini is up
   (see §5).
3. **AMT Configuration → Network Setup**
   - DHCP enabled (router-side reservation will lock the IP)
   - Hostname: `mini-amt` (optional; helps distinguish AMT-side reverse DNS)
4. **AMT Configuration → SOL/IDER/KVM**
   - SOL enabled
   - IDER enabled
   - KVM enabled
   - **User consent: None** (required for true unattended access; tradeoff
     accepted in `mini.md` §6.3)
5. **Activate Network Access** → Client Control Mode (CCM)
6. Save & exit MEBx

Verify from another LAN host:

```bash
curl -k https://<mini-amt-ip>:16993/   # should return AMT auth challenge
amtterm <mini-amt-ip>                  # SOL test (will prompt for password)
```

Once verified, every subsequent step can be done remotely via AMT KVM.

---

## 4. Install — disko + nixos-install

Boot the installer (USB or via AMT IDER + KVM), open a terminal.

### 4.1 Network on the installer (wifi for first boot)

Ethernet hasn't been routed to mini's final position yet — bring up wifi on
the installer so we can `git clone` and `nixos-install` without moving cables.

```bash
sudo systemctl start NetworkManager
ip link                                 # confirm the wireless iface name (e.g. wlan0)
nmcli radio wifi on
nmcli device wifi rescan
nmcli device wifi list                  # find the SSID
nmcli device wifi connect "<SSID>" password "<password>"
ping -c 3 1.1.1.1                       # sanity check
```

The declarative static-ethernet profile in `hosts/mini/default.nix` only
applies after `nixos-install`; the wifi connection lives in the installer's
in-memory NetworkManager and disappears on reboot. Wire ethernet up before
§4.5 (reboot) or be ready to bring wifi back up on the installed system.

### 4.2 Find the NVMe id, edit disko.nix

```bash
ls -l /dev/disk/by-id/ | grep nvme
# nvme-WD_BLACK_SN770_250GB_xxxxxxxxxxxx -> ../../nvme0n1
```

Clone the flake, edit disko.nix's `device =` to the real id:

```bash
sudo -i
cd /tmp
git clone https://github.com/jadeezomg/flake.git
cd flake
$EDITOR hosts/mini/disko.nix    # paste the real nvme-... id
```

### 4.3 Run disko

**Destroys all data on the target NVMe.** Verify the device id one more time.

```bash
sudo nix --extra-experimental-features 'nix-command flakes' run \
  github:nix-community/disko -- \
  --mode disko --flake .#mini
```

This formats the disk, creates the GPT layout (2GiB ESP + btrfs root with
subvolumes), and mounts everything under `/mnt`.

### 4.4 nixos-install (bootstrap mode)

`hosts/mini/default.nix` has `bootstrap = true` set (see §1.2). In this
mode jadee is created with `initialPassword = "changeme"` and the
sops-managed `hashedPasswordFile` is *not* declared — this avoids the
chicken-and-egg where sops-nix can't decrypt before mini's SSH host key
(its age key source) exists.

```bash
sudo nixos-install --flake .#mini --no-root-password
```

`--no-root-password` is fine — root stays locked, jadee has wheel. Don't
override the user password prompt here; the declarative `initialPassword`
will be applied at first boot.

After §5.4 succeeds, flip `bootstrap = true` → `false` in
`hosts/mini/default.nix`, commit, and run `just switch` (§5.5) to swap to
the sops-managed password.

### 4.5 Reboot

```bash
sudo reboot
# Eject USB during reboot if you used path 2.1
```

---

## 5. First boot — host key + sops + manual switch

### 5.1 Verify boot

Either via attached display (still works pre-headless) or via AMT KVM.
Login as `jadee` with the temp password from §4.4.

### 5.2 Verify network

```bash
ip a                            # confirm static IP came up
ping -c 3 1.1.1.1
ssh-keygen -A                   # ensure host keys exist
```

### 5.3 SSH from workstation

From desktop:

```bash
ssh jadee@mini.lan              # or the static IP
```

If this works, AMT KVM is no longer needed for OS-level work — only for
SecureBoot enrollment in §5.6.

### 5.4 Add mini to sops recipients

On mini:

```bash
# Generate mini's age key from its SSH host key
nix-shell -p ssh-to-age --run \
  'sudo cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age'
# → age1abc...   ← copy this
```

On workstation, edit `.sops.yaml` (top of repo) — add `&mini` alongside the
existing host recipients and include it in the `creation_rules`:

```yaml
keys:
  - &framework age1pmtv9wwwfmsjp5pud8afv7c6cvjyc54t2attmr5wukvvtnu0kdvqsrxmj2
  - &desktop   age1s6yrgxcpwm8qy3cpjc2fz6pyq76afd33e2kfg7q58q69ehxwzd2s6qjrxu
  - &caya      age1yrt6l02984f5gemerpzlf5v4ymakdmf45qhu3ecy2qtjwuzn43tqh755nz
  - &mini      age1abc...               # NEW — paste output from above

creation_rules:
  - path_regex: secrets/[^/]+\.(yaml|json|env|ini)$
    key_groups:
      - age:
          - *framework
          - *desktop
          - *caya
          - *mini
```

Re-encrypt:

```bash
sops updatekeys secrets/secrets.yaml
git add .sops.yaml secrets/secrets.yaml
git commit -m "feat(secrets): add mini host recipient"
git push
```

### 5.5 Switch on mini (post-bootstrap)

Flip the bootstrap flag in `hosts/mini/default.nix` (see §4.4) so the
sops-managed password takes over, then switch:

```bash
# On workstation
$EDITOR hosts/mini/default.nix    # bootstrap = true  →  bootstrap = false
git commit -am "feat(mini): exit bootstrap mode"
git push
```

```bash
# On mini
cd ~/.dotfiles/flake          # if not already cloned: git clone ...
git pull
just init                     # writes .flake-host = mini
                              # (recipe just writes the file; no build is
                              #  triggered. Verified against Justfile §init.)
just switch
```

After this:
- jadee's password is the sops-managed one
- All declarative config is live

### 5.5.1 Tailscale — first-time login

The tailscale daemon runs (declared in `modules/nixos/networking.nix` with
`extraUpFlags = ["--ssh"]`), but the node is not yet logged into the
tailnet. Run once, manually:

```bash
sudo tailscale up --ssh
# → opens an https://login.tailscale.com/... URL
# → copy it to a browser on a logged-in device and approve
tailscale status                 # mini should now show up
tailscale ip -4                  # note the 100.x.x.x address
```

After this `ssh jadee@mini.<tailnet>.ts.net` works from any tailnet peer,
and the ACL-gated tailscale SSH path is live.

### 5.6 Lanzaboote SecureBoot enrollment

Order matters here — see the **SecureBoot ordering note** in §5.6.1 below.
The short version:

```bash
# On mini — 1. generate keys
sudo sbctl create-keys

# 2. switch FIRST — lanzaboote writes signed .efi files to /boot
just switch

# 3. verify lanzaboote signed everything
sudo sbctl verify              # all .efi entries should report "signed"

# 4. now enroll keys into firmware (UEFI must be in Setup Mode — see 5.6.1)
sudo sbctl enroll-keys -m      # -m = include Microsoft KEK + DB
```

Reboot via AMT, enter firmware (Del/F2 during POST), enable SecureBoot,
save & exit. Mini boots SecureBoot-validated.

```bash
sudo sbctl status               # confirm "Secure Boot: enabled"
sudo sbctl verify               # confirm all kernels/efi binaries pass
```

#### 5.6.1 SecureBoot ordering note

The previous version of this doc had `enroll-keys` before `nixos-rebuild
switch`. That **breaks**: if you enroll keys into firmware before lanzaboote
has installed signed binaries onto the ESP, the next boot fails — firmware
will refuse to load unsigned files.

Correct order:

1. `sbctl create-keys` — generate the PKI bundle at `/var/lib/sbctl`.
2. `nixos-rebuild switch` (or `just switch`) — lanzaboote picks up the bundle
   and writes **signed** boot files to `/boot/EFI/Linux/`.
3. `sbctl verify` — confirm every entry on the ESP is signed.
4. Put the firmware into **Setup Mode**: in MEBx or BIOS, find "SecureBoot →
   Reset to Setup Mode" / "Clear PK". On the MS-01 this is under the
   Security menu. (Without Setup Mode, `sbctl enroll-keys` will fail or
   silently no-op because the firmware refuses to accept new platform keys.)
5. `sbctl enroll-keys -m` — `-m` (or `--microsoft`) imports Microsoft's KEK
   + DB alongside our own, so OEM firmware capsules and fwupd updates keep
   working. Skip the flag and you'll brick fwupd capsule updates.
6. Reboot, enable SecureBoot in firmware (now it has keys to validate
   against), save, exit. `sbctl status` should report `Secure Boot:
   enabled`.

If something goes wrong: boot into firmware, clear all SecureBoot keys
(returns to Setup Mode), reboot to the OS, redo from step 1.

### 5.7 Mirror AMT password into sops

On workstation:

```bash
sops secrets/secrets.yaml      # paste the MEBx password into mini.amt.password
git add secrets/secrets.yaml
git commit -m "feat(secrets): record mini AMT password"
git push
```

(This is for your own recovery, not consumed declaratively.)

---

## 6. Cache-warming pipeline — DEFERRED

Wiring the cachix nightly pipeline is **deferred** until after the host runs
reliably on its own. Goal: bring up SSH + sops + lanzaboote + hermes first,
prove stability, then turn on the bot.

The nix code for the pipeline already exists at
[`hosts/mini/flake-cache-warm.nix`](../../hosts/mini/flake-cache-warm.nix).
The import is **commented out** in `hosts/mini/default.nix`. To bring it
online (one-time bootstrap):

1. **Create the cache** — workstation:
   ```bash
   cachix authtoken <personal-token>
   cachix create jadee-flake             # public read
   cachix use jadee-flake                 # prints the public key
   ```
   Paste the printed `jadee-flake.cachix.org-1:<pubkey>=` into
   `modules/shared/environment.nix` (replacing the `# TODO: replace…` line).

2. **Push-scoped auth token**:
   ```bash
   cachix authtoken --create-token --scope push --cache jadee-flake
   sops secrets/secrets.yaml              # cachix/auth-token = <token>
   ```

3. **Deploy key** — on mini:
   ```bash
   ssh-keygen -t ed25519 -N '' -C 'mini@flake-bot' -f /tmp/mini-deploy-key
   cat /tmp/mini-deploy-key.pub          # → register on github.com/jadeezomg/flake
   ```
   GitHub UI → repo Settings → Deploy keys → Add → ✅ Allow write access.
   Then on workstation:
   ```bash
   ssh jadee@mini cat /tmp/mini-deploy-key
   sops secrets/secrets.yaml              # mini/git/deploy-key = <multiline>
   ssh jadee@mini rm /tmp/mini-deploy-key{,.pub}
   ```

4. **Enable the import** — uncomment `./flake-cache-warm.nix` in
   `hosts/mini/default.nix`, commit, push.

5. **Switch + first manual run**:
   ```bash
   # On mini
   git pull && just switch
   sudo systemctl start flake-cache-warm.service
   journalctl -fu flake-cache-warm.service
   ```
   Expected: clones repo into `/var/lib/flake-cache-warm/flake`, runs
   `nix flake update`, builds three closures, pushes new paths to
   `jadee-flake.cachix.org`, commits + pushes lockfile bump to `main`.

6. **Verify** — on desktop:
   ```bash
   git pull && just switch
   # output should show "copying path '/nix/store/...' from 'https://jadee-flake.cachix.org'"
   ```

Tracked in `mini.md` §11 as the top deferred TODO.

---

## 7. hermes-agent — first run

```bash
# On workstation
sops secrets/secrets.yaml     # populate hermes.env with API keys
git commit + push

# On mini
git pull
just switch
systemctl status hermes-agent.service
journalctl -fu hermes-agent.service
```

If the service starts cleanly, hermes is live. Iterate on
`hosts/mini/hermes.nix`'s `settings = { ... }` block per the hermes-agent
README to configure model/provider/skills.

---

## 8. Smoke test

Run-through after everything above is done:

| Check | Expected |
|---|---|
| `ssh jadee@mini` from desktop | succeeds with key auth, no password |
| `ssh jadee@mini.<tailnet>.ts.net` | succeeds via Tailscale SSH |
| `sudo whoami` on mini | `root` with no password prompt |
| `sbctl status` on mini | `Secure Boot: enabled` |
| `amtterm <mini-amt-ip>` from desktop | SOL prompt |
| `https://<mini-amt-ip>:16993` from a browser | AMT web UI |
| `systemctl status hermes-agent.service` | `active (running)` |

After the §6 cache-warming bootstrap (deferred), additionally:

| Check | Expected |
|---|---|
| `systemctl list-timers flake-cache-warm.timer` | scheduled for 06:00 |
| `curl -fsS https://jadee-flake.cachix.org/nix-cache-info` | returns store info |
| `just switch` on desktop after a `git pull` | substitutes from `jadee-flake.cachix.org` |

---

## 9. After install — what's still pending

Pulled forward from `mini.md` §11:

- Power tuning (kept stock; revisit once stable)
- Monitoring stack (defer; revisit when needed)
- Backups (real gap; address before storing anything important)
- Other services (out of scope; basics first)
- Storage future (deferred until 2nd NVMe)
- Stylix/DMS/Niri inertness check (verify during a `just build-dry`)
- Tailscale subnet router for AMT-over-VPN (skip until needed)
