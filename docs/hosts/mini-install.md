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

### 1.3 Sops state on workstation (pre-install)

`secrets/secrets.yaml` does **not** yet include mini-encrypted secrets — mini's
host age key only exists once the OS is installed (§5.4). Until then the
secret schema below should be planned but the encrypted values added in §5–§7:

| Sops path | Source | Used by |
|---|---|---|
| `users/jadee/password` | `mkpasswd -m sha-512` (deterministic across hosts) | `users.users.jadee.hashedPasswordFile` |
| `cachix/auth-token` | `cachix authtoken --create-token --scope push --cache jadee-flake` | `flake-cache-warm.service` `LoadCredential` |
| `mini/git/deploy-key` | `ssh-keygen -t ed25519` on mini, paste private key here | `flake-cache-warm.service` `LoadCredential` |
| `mini/amt/password` | the MEBx password set in §3 | reference only (not consumed declaratively) |
| `hermes/env` | API keys for the agent | `services.hermes-agent.environmentFiles` (declared at `hosts/mini/hermes.nix`, currently optional) |

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

Make a USB stick:

```bash
# On workstation
nix run nixpkgs#disko -- --help    # sanity check disko CLI works
ISO=$(nix build --print-out-paths github:NixOS/nixpkgs#nixos-installer-graphical-gnome.config.system.build.isoImage --no-link)
sudo dd if=$ISO of=/dev/sdX bs=4M status=progress conv=fsync
```

Or download `nixos-25.11-minimal-x86_64-linux.iso` and use `dd` /
`bootable-usb-creator`.

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

### 4.1 Network on the installer

```bash
sudo systemctl start NetworkManager
nmcli device wifi list                  # if needed; mini has ethernet
nmcli con add type ethernet con-name lan ifname enp2s0f0
sudo nmcli con up lan
```

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

### 4.4 nixos-install

```bash
sudo nixos-install --flake .#mini --no-root-password
```

The `--no-root-password` flag is fine — root is locked, jadee has wheel.

When it asks for a password (for the user), set a temporary one. Sops will
override it on next switch.

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

On workstation, edit `.sops.yaml` (top of repo):

```yaml
keys:
  - &jadee age1...                  # existing
  - &mini  age1abc...               # new — paste output from above
creation_rules:
  - path_regex: secrets/secrets.yaml
    key_groups:
      - age:
          - *jadee
          - *mini
```

Re-encrypt:

```bash
sops updatekeys secrets/secrets.yaml
git add .sops.yaml secrets/secrets.yaml
git commit -m "feat(secrets): add mini host recipient"
git push
```

### 5.5 Switch on mini

```bash
# On mini
cd ~/.dotfiles/flake          # if not already cloned, git clone first
git pull
just init                     # writes .flake-host = mini (verify just recipe behaviour)
just switch
```

After this:
- jadee's password is the sops-managed one
- All declarative config is live

### 5.6 Lanzaboote SecureBoot enrollment

From workstation, attach to mini via AMT KVM (you'll need to reboot into
firmware):

```bash
# On mini
sudo sbctl create-keys
sudo sbctl enroll-keys --microsoft     # --microsoft preserves OEM/fwupd capsule signing
sudo nixos-rebuild switch --flake .#mini
```

Reboot via AMT, enter firmware (Del/F2 during POST), enable SecureBoot,
save & exit. Mini boots SecureBoot-validated.

```bash
sudo sbctl status               # confirm "Secure Boot: enabled"
sudo sbctl verify              # confirm all kernels/efi binaries pass
```

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
