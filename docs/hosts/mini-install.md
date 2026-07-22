# Mini — First-time setup guide

End-to-end install walkthrough for the `mini` host. Companion to
[`mini.md`](./mini.md) (design doc — read first to understand the *why*).

**Recommended order (cold start):**

1. §1 — workstation prep (flake eval, SSH keys, network values in git)
2. §2 — MEBx / AMT (one physical POST; enables remote KVM afterward)
3. §3 — boot the NixOS installer (USB first time, or AMT IDER once §2 works)
4. §4 — disko + `nixos-install`
5. §5 — first boot, sops host key, `just switch`, Tailscale, SecureBoot
6. §6–§7 — deferred cache-warm; hermes secrets when ready

SecureBoot enrollment stays in §5.6 **after** the OS is installed and reachable.
“AMT first” means **MEBx before relying on remote KVM** — not before the USB
installer on a brand-new box.

---

## 0. Prerequisites

- Physical access to the mini at least once (for MEBx — §2)
- A USB stick (NixOS minimal installer ISO ≥ 25.11) **or**, after §2, AMT IDER +
  KVM from the workstation
- Workstation (desktop) with this flake checked out, `sops` working, and
  **`just`** on PATH (or use `flake` / `zf` after HM switch — see
  [`ALIASES.md`](../ALIASES.md))
- The mini connected to LAN with one 2.5G NIC plugged in (ethernet to final
  port before §5 if possible)
- Planned **static IP**, gateway, and DNS for the OS NIC in `hosts/mini/default.nix`
- Router: DHCP reservations for the **OS MAC** and **AMT MAC** (same physical
  NIC; AMT and OS share it — reserve one IP for management traffic and one for
  the OS static profile, or use a single reservation if you only DHCP AMT)
- Your desktop **SSH public key** present in `data/users/users.nix` →
  `jadee.sshKeys` (OpenSSH has **password auth disabled** — key auth is required
  from first boot)
- **GitHub push over HTTPS** — GitHub does not accept your login password for
  `git push` to `https://github.com/...`. Use an **SSH remote** (see
  [`mini.md`](./mini.md) repo remote), or run `gh auth login` and
  `gh auth setup-git`, or a [personal access
  token](https://github.com/settings/tokens) when Git asks for a password over
  HTTPS.

---

## 1. Workstation prep — flake changes

**Status: implemented on `main`.** The flake compiles (`nix eval
.#nixosConfigurations.mini.config.system.build.toplevel.drvPath` returns a
valid `.drv`). Below is what landed and the inline TODO markers that **must be
filled in** before `nixos-install`.

### 1.1 What was changed

| File | Change |
|---|---|
| `flake.nix` | new inputs: `disko` (`github:nix-community/disko`), `hermes-agent` (`github:NousResearch/hermes-agent`) — both with `nixpkgs.follows` |
| `hosts/mini/default.nix` | imports `inputs.disko.nixosModules.disko` and `inputs.hermes-agent.nixosModules.default` (moved out of the generic factory) |
| `modules/nixos/boot.nix` | kernel branches on `server.enable` (cachyos-server vs cachyos-latest-zen4); plymouth gated `lib.mkIf (!server.enable)`; lanzaboote unchanged |
| `modules/nixos/networking.nix` | NixOS `networking.firewall` activated when `server.enable` (drops firewalld/firewalld-gui/proton-vpn/wireguard-ui/networkmanagerapplet from systemPackages on server hosts) |
| `modules/profiles/server.nix` | body emptied — `server.enable` is a steering toggle, gating happens inline in `boot.nix`/`networking.nix` |
| `data/users/users.nix` | `jadee.sshKeys` → `authorizedKeys` on all NixOS hosts (verify your desktop key is listed) |
| `modules/nixos/user.nix` | consumes `userConfig.sshKeys` → `users.users.${user}.openssh.authorizedKeys.keys` |
| `modules/shared/environment.nix` | added `https://jadee-flake.cachix.org` substituter + TODO marker for the trusted public key |
| `modules/profiles/desktop/` | desktop HM tree (niri/DMS/dconf) pushed only when `desktop.enable` — headless hosts skip it |
| `hosts/hosts.nix` | registered `mini = import ./mini/host.nix` |
| `hosts/mini/*` | full new host: `host.nix`, `profiles.nix`, `default.nix`, `hardware-configuration.nix`, `disko.nix`, `hermes.nix`, `flake-cache-warm.nix` |
| `flake.lock` | locked disko + hermes-agent |

### 1.2 SSH keys (required before install)

`modules/nixos/openssh.nix` sets `PasswordAuthentication = false`. The first
boot must already include your public key in `data/users/users.nix`:

```bash
# On workstation — confirm your key is in the list (add more if needed)
grep -A5 sshKeys data/users/users.nix
git commit -am "feat(mini): authorize SSH keys for jadee" && git push
```

**If SSH fails after install:** use local console or AMT KVM, log in as `jadee` /
`changeme`, fix `~/.ssh/authorized_keys` temporarily, or re-run install after
pushing the correct key — do not expect password SSH.

### 1.3 Inline TODO markers that block install

Search `git grep -n TODO` for the canonical list. As of writing:

| Location | Action before install |
|---|---|
| `data/users/users.nix` (`jadee.sshKeys`) | every key you need from desktop/framework; commit before `nixos-install` |
| `modules/shared/environment.nix:43` | paste the real `jadee-flake.cachix.org-1:<pubkey>=` (only after `cachix create jadee-flake` — see §6; OK to defer) |
| `hosts/mini/disko.nix` (both `device =`) | real `/dev/disk/by-id/nvme-…` paths from the live ISO (§4.2) |
| `hosts/mini/default.nix` (`mini-lan` profile) | real static IP, gateway, DNS, and `interface-name` (see §1.5) |
| `hosts/mini/host.nix` (`miniBootstrap`) | **removed post-bootstrap** — re-introduce the toggle (skip sops password + LLM stack) when reinstalling from scratch |
| `hosts/mini/host.nix` (`miniLlmHosting`) | leave `false` until you want the local chat stack; set `true` after bootstrap is off, then see `docs/hosts/mini-llm-hosting.md` |

### 1.4 Network values — commit on workstation **or** edit on the installer

Pick **one** workflow before `nixos-install`:

**A — commit-first (recommended):** on the workstation, set real values in
`hosts/mini/default.nix` (`networking.networkmanager.ensureProfiles.profiles."mini-lan"`),
commit, push. On the installer: `git clone` / `git pull` and use that tree for
§4 — no extra edit besides `disko.nix`.

**B — installer-only:** edit both `hosts/mini/disko.nix` and
`hosts/mini/default.nix` in the `/tmp/flake` clone (§4.2). Copy the network
block back to the workstation and commit after install so git stays canonical.

On the live ISO, discover the wired interface name:

```bash
ip link    # e.g. enp2s0f0 — must match interface-name in the profile
```

### 1.5 Sops state on workstation (pre-install)

`users/jadee/password_mini` may already exist in `secrets/secrets.yaml`, but
mini **cannot decrypt** anything until §5.4 (`&mini` in `.sops.yaml` + host age
key on the machine). Until then, bootstrap mode uses `initialPassword = "changeme"`.

Canonical schema lives in [`secrets/SCHEMA.md`](../../secrets/SCHEMA.md).
Mini-relevant entries (quick reference):

| Sops path | When to add |
|---|---|
| `users/jadee/password_mini` | **before §5.5** — required in secrets before `miniBootstrap = false` (see §5.4 checklist) |
| `mini/amt/password` | §5.7 (after MEBx is set up) |
| `mini/git/deploy-key` | §6 (cache-warm bootstrap, deferred) |
| `cachix/auth-token` | §6 (cache-warm bootstrap, deferred) |
| `hermes/env` | §7 (hermes first run) |

Re-encrypt with `sops updatekeys secrets/secrets.yaml` after adding mini's
age recipient in §5.4 — schema and command details are in `SCHEMA.md`.

### 1.6 Pre-install verification

```bash
just fmt
nix flake check --no-build
nix eval .#nixosConfigurations.mini.config.system.build.toplevel.drvPath
```

The flake should evaluate clean for `mini` and `desktop`. (`framework` may still
hit a pre-existing upstream `fw-fanctrl` issue unrelated to mini.)

---

## 2. MEBx provisioning — vPro / AMT one-time setup

Physical access required once. Do this **before** depending on AMT KVM for
install (§3.2). On a cold start you can still use USB (§3.1) without MEBx,
but provisioning here unlocks headless install and recovery afterward.

1. Power on mini, hit `Ctrl+P` during POST → MEBx menu
2. Default password: `admin` → forced change. Use a strong password
   (≥8 chars, upper+lower+digit+special). **Save it in your password
   manager AND mirror to sops** as `mini/amt/password` once mini is up
   (§5.7).
3. **AMT Configuration → Network Setup**
   - DHCP enabled (router-side reservation will lock the AMT IP)
   - Hostname: `mini-amt` (optional; helps distinguish AMT-side reverse DNS)
4. **AMT Configuration → SOL/IDER/KVM**
   - SOL enabled
   - IDER enabled
   - KVM enabled
   - **User consent: None** (required for true unattended access; tradeoff
     accepted in `mini.md` §6.3)
5. **Activate Network Access** → Client Control Mode (CCM)
6. Save & exit MEBx

Verify from the workstation (desktop does not yet ship `amtterm` via a profile —
use a one-off nix shell until `devenv.amt.enable` exists):

```bash
curl -k https://<mini-amt-ip>:16993/   # should return AMT auth challenge
nix shell nixpkgs#amtterm -c amtterm <mini-amt-ip>   # SOL test (AMT password)
```

**KVM / IDER (§3.2 installs):** mount the same minimal ISO through AMT IDER
(Intel AMT web UI or vendor tooling), then open a remote KVM session
(`tigervnc`, Remmina, or the browser KVM in the AMT UI on `:16994` depending on
firmware). Exact clicks vary by AMT version — goal is booting the installer ISO
without a USB stick.

Once verified, subsequent OS work can use SSH; keep AMT for firmware and
SecureBoot (§5.6).

---

## 3. Boot the NixOS installer on mini

### 3.1 Path A — physical USB (typical cold start)

Grab the official **minimal** ISO from https://nixos.org/download (pick the
≥25.11 minimal x86_64 image). Don't build from the flake — there's no
ready-made `isoImage` attribute on `nixpkgs` to point a `nix build` at, and
rolling a custom installer adds drift for no benefit here.

> **Reminder — adjust the device path before `dd`.** Run `lsblk` first and
> double-check `/dev/sdX` is the USB stick and not an internal disk.

```bash
# On workstation — replace /dev/sdX with the actual USB device
lsblk
sudo dd if=~/Downloads/nixos-minimal-25.11-x86_64-linux.iso         of=/dev/sdX bs=4M status=progress conv=fsync
sync
```

Plug into mini, boot, F11 (boot menu) → USB.

### 3.2 Path B — AMT IDER + KVM (after §2)

Re-mount the minimal ISO over IDER from the workstation, boot via remote KVM.
Skip USB once this path is reliable.

---

## 4. Install — disko + nixos-install

Boot the installer (USB or via AMT IDER + KVM), open a terminal.

### 4.1 Network on the installer (wifi for first boot)

Ethernet hasn't been routed to mini's final position yet — bring up wifi on
the installer so we can `git clone` and `nixos-install` without moving cables.

```bash
sudo systemctl start NetworkManager
ip link                                 # confirm the wireless iface name

iface=wlp91s0                           # replace if `ip link` shows a different name
ssid="<SSID>"
bssid="AA:BB:CC:DD:EE:FF"              # BSSID from `nmcli ... wifi list`

# Some APs/routers get confused by NetworkManager scan MAC randomization during
# installer sessions. Disable it in the live environment before connecting.
sudo mkdir -p /etc/NetworkManager/conf.d
printf '[device]\nwifi.scan-rand-mac-address=no\n' \
  | sudo tee /etc/NetworkManager/conf.d/10-disable-wifi-randmac.conf
sudo systemctl restart NetworkManager

nmcli radio wifi on
nmcli device wifi rescan ifname "$iface"
nmcli -f IN-USE,BSSID,SSID,SIGNAL,SECURITY device wifi list ifname "$iface"

# Normal case: connect by SSID.
nmcli device wifi connect "$ssid" password "<password>" ifname "$iface"

# If the SSID is listed but `connect "$ssid"` says it cannot find it, target
# the exact access point from the BSSID column. `connect` still takes the SSID;
# BSSID is a separate option.
nmcli device wifi connect "$ssid" bssid "$bssid" password "<password>" ifname "$iface"

ping -c 3 1.1.1.1                       # sanity check

# If it gets stuck at "connecting (configuring)", association worked but IP
# configuration is stuck. Reset the transient profile, pin the real interface
# MAC for the connection, and retry DHCP-only IPv4.
nmcli device disconnect "$iface"
nmcli connection delete "$ssid" || true
nmcli device wifi connect "$ssid" bssid "$bssid" password "<password>" ifname "$iface"
nmcli connection modify "$ssid" \
  802-11-wireless.cloned-mac-address permanent \
  ipv4.method auto \
  ipv6.method disabled
nmcli connection up "$ssid" ifname "$iface"
nmcli device show "$iface" | grep -E 'IP4|GENERAL.STATE'
```

The declarative static-ethernet profile in `hosts/mini/default.nix` only
applies after `nixos-install`; the wifi connection lives in the installer's
in-memory NetworkManager and disappears on reboot. Wire ethernet up before
§4.5 (reboot) or be ready to bring wifi back up on the installed system.

### 4.2 Find both NVMe ids, edit disko.nix (+ network if needed)

```bash
lsblk -o NAME,SIZE,MODEL,SERIAL,TYPE,MOUNTPOINTS
ls -l /dev/disk/by-id/ | grep nvme
# nvme-..._256GB_... -> ../../nvme0n1  # system SSD
# nvme-..._2TB_...   -> ../../nvme1n1  # /srv application-storage SSD
```

Clone the flake (use the branch/commit you prepared in §1). Edit **disko.nix**
and, if you did not commit network values in §1.4A, **default.nix** too:

```bash
sudo -i
cd /tmp
git clone https://github.com/jadeezomg/flake.git
cd flake
git pull    # if you committed network/disko fixes from the workstation
$EDITOR hosts/mini/disko.nix    # both real nvme-... ids (required)
# Only if §1.4B:
$EDITOR hosts/mini/default.nix  # mini-lan static IP, gateway, DNS, interface-name
```

### 4.3 Run disko

**Destroys all data on both selected NVMe disks.** Verify the 256 GB system SSD
and 2 TB application-storage SSD ids one more time.

```bash
sudo nix --extra-experimental-features 'nix-command flakes' run \
  github:nix-community/disko -- \
  --mode disko --flake .#mini
```

This formats both disks, creates a 1GiB ESP + btrfs system root (including
`/nix`) on the 256 GB SSD, creates a separate btrfs `/srv` filesystem on the
2 TB SSD for service/application data, and mounts everything under `/mnt`.

### 4.4 nixos-install (bootstrap mode)

`hosts/mini/host.nix` has `miniBootstrap = true` set (see §1.2). In this
mode jadee is created with `initialPassword = "changeme"` and the
sops-managed `hashedPasswordFile` is *not* declared — this avoids the
chicken-and-egg where sops-nix can't decrypt before mini's age host key
exists at `/var/lib/private/sops/age/keys.txt`.

```bash
sudo nixos-install \
  --flake .#mini \
  --no-root-password \
  --max-jobs 1 \
  --cores 4 \
  --show-trace \
  --log-format bar-with-logs \
  --option log-lines 200
```

`--max-jobs 1 --cores 4` is intentional for the 24 GiB installer environment:
the target config also caps `mini` to four build cores, but `nixos-install`
uses the live installer's Nix daemon while building the closure.

`--no-root-password` is fine — root stays locked, jadee has wheel. Don't
override the user password prompt here; the declarative `initialPassword`
will be applied at first boot.

After §5.4 succeeds, flip `miniBootstrap = true` → `false` in
`hosts/mini/host.nix`, commit, and run `just switch` (§5.5) to swap to
the sops-managed password.

### 4.5 Reboot

```bash
sudo reboot
# Eject USB during reboot if you used §3.1
```

---

## 5. First boot — age host key + sops + manual switch

### 5.1 Verify boot

Either via attached display (still works pre-headless) or via AMT KVM.
Login as `jadee` with the temp password from §4.4.

### 5.2 Verify network

```bash
ip a                            # confirm static IP came up
ping -c 3 1.1.1.1
systemctl status sshd             # openssh enabled via modules/nixos/openssh.nix
```

### 5.3 SSH from workstation

From desktop (key auth only — no password SSH):

```bash
ssh jadee@<static-ip>           # use the IP from hosts/mini/default.nix
# optional if you configured DNS/mDNS for the hostname:
# ssh jadee@mini.lan
```

If this works, AMT KVM is no longer needed for OS-level work — only for
SecureBoot enrollment in §5.6.

**Kitty locally:** SSH forwards `TERM=xterm-kitty`. After `just switch` on mini,
`environment.enableAllTerminfo` is enabled so `systemctl`, pagers, etc. recognise
that type. Until the next switch, use `kitty +kitten ssh …`, or
`SetEnv TERM=xterm-256color` for that host in `~/.ssh/config`.

**SSH fails?** Console or AMT KVM → `jadee` / `changeme` → verify
`~/.ssh/authorized_keys` or fix keys in git and reinstall.

### 5.3.1 Clone the flake on mini (required once)

The installer clone under `/tmp/flake` is gone after reboot. Before `just`
commands work, install the live checkout at `~/.dotfiles/flake` (default
`dotfiles.flakeRoot`):

```bash
mkdir -p ~/.dotfiles
git clone https://github.com/jadeezomg/flake.git ~/.dotfiles/flake
cd ~/.dotfiles/flake
just _init mini    # writes .flake-host = mini (non-interactive)
```

`just` is on **system** PATH via **`dotfiles.profiles.devenv.tools`** (mini has
`devenv.enable = true` with heavy sub-profiles trimmed in
`hosts/mini/profiles.nix` — see comment there). On a **very** old generation
before that landed, use **`nix shell nixpkgs#just -c just …`** once-off.

### 5.4 Bootstrap mini age host key + workstation secrets

On mini (after §5.3.1):

```bash
cd ~/.dotfiles/flake
just bootstrap-sops-host-key    # first install only — host path must be empty
# → age1abc...   ← copy this
```

**Blocking checklist (workstation) — complete before §5.5:**

- [ ] `users/jadee/password_mini` in `secrets/secrets.yaml` (`mkpasswd -m sha-512` hash)
- [ ] `&mini` in `.sops.yaml` with pubkey from above
- [ ] `- *mini` under `creation_rules`
- [ ] `sops updatekeys secrets/secrets.yaml` run and committed

On workstation, edit `.sops.yaml` — uncomment and set `&mini`, add `- *mini` to
`creation_rules`:

```yaml
keys:
  - &editor    age1pmtv9wwwfmsjp5pud8afv7c6cvjyc54t2attmr5wukvvtnu0kdvqsrxmj2
  - &framework age1…
  - &desktop   age1…
  - &caya      age1…
  - &mini      age1abc...               # NEW — paste output from above

creation_rules:
  - path_regex: secrets/[^/]+\.(yaml|json|env|ini)$
    key_groups:
      - age:
          - *editor
          - *framework
          - *desktop
          - *caya
          - *mini
```

Full reference: [docs/secrets/sops-age-keys.md](../secrets/sops-age-keys.md).

Re-encrypt:

```bash
sops updatekeys secrets/secrets.yaml
git add .sops.yaml secrets/secrets.yaml
git commit -m "feat(secrets): add mini host recipient"
git push
```

Add `password_mini` if not done yet:

```bash
mkpasswd -m sha-512
sops secrets/secrets.yaml
```

### 5.5 Switch on mini (post-bootstrap)

**Do not flip `miniBootstrap` to `false` until the §5.4 checklist is complete.**

Flip `miniBootstrap` in `hosts/mini/host.nix` (see §4.4) so the
sops-managed password takes over, then switch:

```bash
# On workstation
$EDITOR hosts/mini/host.nix    # miniBootstrap = true  →  miniBootstrap = false
git commit -am "feat(mini): exit bootstrap mode"
git push
```

**Editor age key on mini (before `just switch`):** Home Manager decrypts user
secrets with the same **editor** private key as on your workstation — the file
at `~/.config/sops/age/keys.txt` (see [docs/secrets/sops-age-keys.md](../secrets/sops-age-keys.md)).
NixOS secrets still use the **host** key under `/var/lib/private/sops/age/keys.txt`;
that path alone is not enough for HM `sops-nix.service`. Copy the editor key over
first (tight perms: directory `0700`, file `0600`). Use the **same
`jadee@…` target that already works for plain `ssh` in §5.3** (usually the
**static LAN IP** from `hosts/mini/default.nix`). Bare `mini` only works if
something on your network resolves that name — otherwise SSH sits in **DNS
lookup** or **TCP connect** and `scp` looks like it “hangs”. After Tailscale
(§5.5.1), `jadee@mini.<tailnet>.ts.net` is fine too.

```bash
MINI=jadee@192.168.x.x    # replace with your working SSH target

ssh -o ConnectTimeout=10 "$MINI" 'mkdir -p ~/.config/sops/age'
scp -o ConnectTimeout=10 ~/.config/sops/age/keys.txt "$MINI:~/.config/sops/age/keys.txt"
ssh "$MINI" chmod 600 ~/.config/sops/age/keys.txt
```

If it still stalls, run **`ssh -vvv "$MINI"`** (or `scp -v …`) and note the
last line printed before the long pause — that pinpoints DNS vs TCP vs auth.

**No working network path?** Copy the key out-of-band (USB, AMT KVM paste into
`nano`, or `cat keys.txt | ssh … 'cat > ~/.config/sops/age/keys.txt'` from a
shell that *does* reach mini).

```bash
# On mini
cd ~/.dotfiles/flake
git pull
just verify-sops-host-key mini
# .flake-host should already be mini from §5.3.1; if not: just _init mini
just switch
```

After this:
- jadee's password is the sops-managed one
- All declarative config is live
- HM user secrets exist under `~/.config/…`; `sops-session-env.nix` can export them
  to the user session (see [README](../../README.md) Secrets).

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

`hosts/mini/host.nix` starts with `secureBoot = false`, so the first install
uses plain systemd-boot. Enable lanzaboote only after `/var/lib/sbctl` exists.

```bash
# On mini — 1. generate keys
sudo sbctl create-keys

# 2. In the flake, flip hosts/mini/host.nix:
# secureBoot = false; -> secureBoot = true;
# Commit/push or edit the local checkout on mini.

# 3. switch — lanzaboote writes signed .efi files to /boot
just switch

# 4. verify lanzaboote signed everything
sudo sbctl verify              # all .efi entries should report "signed"

# 5. now enroll keys into firmware (UEFI must be in Setup Mode — see 5.6.1)
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
switch`, and the initial mini config enabled lanzaboote before sbctl keys
existed. Both break:

- enrolling keys into firmware before lanzaboote has installed signed binaries
  onto the ESP makes the next boot fail — firmware refuses unsigned files.
- enabling lanzaboote before `/var/lib/sbctl` exists makes the switch fail
  because there is no PKI bundle for signing.

Correct order:

1. Keep `hosts/mini/host.nix` at `secureBoot = false` for the first
   `nixos-install`.
2. `sbctl create-keys` — generate the PKI bundle at `/var/lib/sbctl`.
3. Flip `hosts/mini/host.nix` to `secureBoot = true`, commit/push or edit the
   local mini checkout.
4. `nixos-rebuild switch` (or `just switch`) — lanzaboote picks up the bundle
   and writes **signed** boot files to `/boot/EFI/Linux/`.
5. `sbctl verify` — confirm every entry on the ESP is signed.
6. Put the firmware into **Setup Mode**: in MEBx or BIOS, find "SecureBoot →
   Reset to Setup Mode" / "Clear PK". On the MS-01 this is under the
   Security menu. (Without Setup Mode, `sbctl enroll-keys` will fail or
   silently no-op because the firmware refuses to accept new platform keys.)
7. `sbctl enroll-keys -m` — `-m` (or `--microsoft`) imports Microsoft's KEK
   + DB alongside our own, so OEM firmware capsules and fwupd updates keep
   working. Skip the flag and you'll brick fwupd capsule updates.
8. Reboot, enable SecureBoot in firmware (now it has keys to validate
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

`services.hermes-agent.enable = true` is on from install, but the unit may stay
**failed/inactive** until `hermes/env` exists in sops — that is expected.

```bash
# On workstation
sops secrets/secrets.yaml     # add hermes/env (KEY=value lines per SCHEMA.md)
git commit -am "feat(secrets): hermes env for mini" && git push

# On mini (after §5.4 — mini must decrypt sops)
cd ~/.dotfiles/flake && git pull && just switch
systemctl status hermes-agent.service
journalctl -fu hermes-agent.service
```

If the service starts cleanly, hermes is live. Iterate on
`hosts/mini/services/hermes.nix`'s `settings = { ... }` block per the hermes-agent
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
| `nix shell nixpkgs#amtterm -c amtterm <mini-amt-ip>` from desktop | SOL prompt |
| `https://<mini-amt-ip>:16993` from a browser | AMT web UI |
| `systemctl status hermes-agent.service` | `active (running)` (after §7 secrets) |

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
- Stylix/DMS/Niri inertness check (verify during a `just build-dry`)
- Tailscale subnet router for AMT-over-VPN (skip until needed)
