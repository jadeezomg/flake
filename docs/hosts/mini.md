# Mini — Headless Server Host (design doc)

Working doc for the new `mini` NixOS host. Decisions captured here are agreed
but not yet implemented. Sections marked **[OPEN]** still need grilling.

---

## 1. Identity & hardware

| Field | Value |
|---|---|
| `hostKey` / hostname | `mini` |
| Chassis | Minisforum MS-01 |
| CPU | Intel Core i5-12600H (4P + 8E, 16 threads, vPro) |
| RAM | 8 GB (will expand later) |
| Storage | 1× 256 GB NVMe (3 NVMe slots total — 2 free for future expansion) |
| NICs | 2× SFP+ 10G (Intel X710), 2× 2.5G (Intel I226-V) — only one 2.5G NIC used initially |
| GPU | Intel UHD (iGPU) |
| Out-of-band mgmt | Intel AMT 16.x (vPro) |
| System | `x86_64-linux` |

Risks flagged:
- 8 GB RAM is tight for a remote builder; some big derivations (chromium, llvm,
  cachyos kernel link step) may OOM. Acceptable until RAM upgrade.
- 256 GB is small for nightly multi-closure builds + nix-store + cachix push
  staging; aggressive GC compensates (see §7).

---

## 2. Profile shape — repurpose `server.enable`

The existing `dotfiles.profiles.server.enable` flag (currently parked: only
postgres + redis) is repurposed as the **headless-server steering wheel**.
When true, it gates desktop assumptions off across the flake.

Refactor scope:

- `modules/nixos/boot.nix`
  - Plymouth: gated `lib.mkIf (!server.enable)`
  - Kernel: when `server.enable`, switch from
    `pkgs.cachyosKernels.linuxPackages-cachyos-latest-zen4` to
    `pkgs.cachyosKernels.linuxPackages-cachyos-server`
  - Lanzaboote / SecureBoot: **kept on** — works headless via AMT KVM for
    one-time `sbctl` enrollment
- `modules/nixos/networking.nix`
  - GUI tools (`networkmanagerapplet`, `firewalld-gui`, `proton-vpn`,
    `wireguard-ui`) gated `lib.mkIf (!server.enable)`
  - `firewalld` package + service replaced by NixOS built-in
    `networking.firewall` (nftables) when `server.enable`
- `parts/hosts.nix`
  - `dms`/`niri`/`stylix` modules left wired (inert when `desktop.enable = false`,
    verify during impl)
- `modules/shared/profiles/server.nix`
  - Replace existing `postgresql + redis` body with the headless-config
    `mkForce` overrides (`desktop.enable = false`, `integrations.enable = false`,
    etc.)

`hosts/mini/profiles.nix` enables `server.enable = true` and whatever else
needs to be on (TBD per service list).

---

## 3. Networking

Stack: keep **NetworkManager** (consistency with desktop/framework — simpler diff).

| Aspect | Decision |
|---|---|
| Active NIC | one 2.5G port (the other 3 NICs left unconfigured) |
| Address | static IP, gateway, DNS — values filled in at impl time |
| Interface naming | predictable defaults (`enp*`) — no link-files renaming |
| Firewall | NixOS `networking.firewall` (nftables); drop firewalld stack |
| LAN SSH | enabled on `:22` |
| Tailscale SSH | already on (global `--ssh` flag) |

Firewall rules:
- `22/tcp` from LAN + `tailscale0`
- AMT firmware ports `16992-16995` are **below the OS firewall** — gated only
  by AMT's own ACL (firmware-level)

---

## 4. Disk + boot — disko + lanzaboote

New flake input: `inputs.disko = { url = "github:nix-community/disko"; inputs.nixpkgs.follows = "nixpkgs"; };`
Wire `inputs.disko.nixosModules.disko` into `parts/hosts.nix` modules list
(NixOS only — Darwin skip).

### 4.1 `hosts/mini/disko.nix`

```nix
{
  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/disk/by-id/nvme-Foobar_256GB_SN1234567"; # fill in real id
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          priority = 1;
          size = "2G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        root = {
          size = "100%";
          content = {
            type = "btrfs";
            extraArgs = [ "-L" "nixos" "-f" ];
            subvolumes = {
              "@root"      = { mountpoint = "/"; };
              "@nix"       = {
                mountpoint = "/nix";
                mountOptions = [ "compress=zstd:3" "noatime" ];
              };
              "@home"      = {
                mountpoint = "/home";
                mountOptions = [ "compress=zstd:3" ];
              };
              "@var-log"   = {
                mountpoint = "/var/log";
                mountOptions = [ "compress=zstd:3" "noatime" ];
              };
              "@snapshots" = { mountpoint = "/.snapshots"; };
            };
          };
        };
      };
    };
  };
}
```

### 4.2 `hosts/mini/hardware-configuration.nix` (minimal; disko owns `fileSystems`)

```nix
{ config, lib, modulesPath, ... }: {
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];
  boot.initrd.availableKernelModules = [ "xhci_pci" "nvme" "usbhid" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];
  networking.useDHCP = lib.mkDefault false;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
```

### 4.3 Swap

No disk swap. Enable `zramSwap.enable = true; zramSwap.memoryPercent = 50;`
on the mini (gated `lib.mkIf server.enable` or directly in mini's `default.nix`).
Add real swap only if OOMs become a recurring issue.

### 4.4 Install flow (one-time, from NixOS minimal ISO booted via AMT KVM)

```bash
# Identify NVMe id, edit disko.nix
ls /dev/disk/by-id/

# Format + mount via disko
sudo nix --extra-experimental-features 'nix-command flakes' run \
  github:nix-community/disko -- --mode disko --flake .#mini

# Install
sudo nixos-install --flake .#mini --no-root-password

# Reboot, then enroll lanzaboote keys (see §4.5)
```

### 4.5 Lanzaboote enrollment (post-install, one-time)

Order: AMT first, then SecureBoot enrollment via AMT KVM.

```bash
# In firmware: disable SecureBoot, boot NixOS once
sudo sbctl create-keys
sudo sbctl enroll-keys --microsoft   # --microsoft preserves OEM/fwupd capsule signing
sudo nixos-rebuild switch --flake .#mini
# Reboot into firmware → re-enable SecureBoot → boot
```

---

## 5. Users & SSH

| Aspect | Decision |
|---|---|
| Primary admin user | `jadee` (same `sharedNixOSUser` from `data/users/users.nix`) |
| `extraUsers` | **stripped** — override `sharedNixOSHost.extraUsers` to `[]` in mini's `host.nix` |
| Service users | dedicated system user per service (e.g. `hermes`); no shell, no home |
| sshd port | `22` |
| sshd auth | `PasswordAuthentication = false`, `PermitRootLogin = no`, `AllowUsers = [ "jadee" ]` |
| Authorized keys | new shared `sshKeys` field added to `data/users/users.nix` user records; `modules/nixos/user.nix` reads it into `users.users.${user}.openssh.authorizedKeys.keys` — applies to all NixOS hosts |
| sudo policy | `wheelNeedsPassword = false` — **only on mini** (gated `hostKey == "mini"` or via `server.enable`); desktop/framework keep password requirement |
| jadee password | sops secret (`users/jadee/password`) → `users.users.jadee.hashedPasswordFile` |

Schema change to `data/users/users.nix`:
```nix
jadee = {
  # ...existing fields...
  sshKeys = [
    "ssh-ed25519 AAAA... jadee@desktop"
    "ssh-ed25519 AAAA... jadee@framework"
    "ssh-ed25519 AAAA... jadee@caya"
  ];
};
```

`modules/nixos/user.nix` extension:
```nix
users.users.${user} = {
  # ...existing...
  openssh.authorizedKeys.keys = userConfig.sshKeys or [];
};
```

---

## 6. Out-of-band management — Intel AMT / vPro

### 6.1 Firmware-side (BIOS / MEBx) — manual, one-time, physical access

1. Boot, `Ctrl+P` during POST → MEBx
2. Change default password (`admin` → strong password, stored in password manager and sops-mirrored as `mini/amt/password`)
3. Network: DHCP with router-side reservation (AMT shares NIC MAC with OS)
4. Enable: SOL (serial-over-LAN), IDER (IDE redirection), KVM (graphical)
5. KVM user consent: **None** — required for true unattended access on a headless box. Tradeoff accepted: anyone with the AMT password gets full unattended console.
6. Activation mode: **Client Control Mode (CCM)** — homelab-appropriate, no enterprise PKI

### 6.2 OS-side — declarative

On mini:
- `services.fwupd.enable = true` (Intel CSME firmware updates from LVFS — critical for AMT CVE patching)
- System packages: `amtterm`, `openwsman`
- `users.groups.amt = {};`
- udev rule: `KERNEL=="mei*", GROUP="amt"`
- `users.users.jadee.extraGroups += [ "amt" ];`

On desktop / framework (controller side) — new toggle:
- `dotfiles.profiles.devenv.amt.enable` (default true on Linux desktops, false on Darwin)
- Adds `amtterm` and a VNC client compatible with AMT's KVM redirection (`tigervnc`/`remmina`) when enabled

### 6.3 Security posture

- AMT runs below the OS — its own TCP/IP, web UI on `:16992`/`:16993`, OOB CPU/RAM access; NixOS firewall does not reach it
- Strong unique password is the primary defense; rotate if compromised
- Keep CSME firmware patched (`fwupd refresh && fwupd update`)
- AMT is **LAN-only initially** — Tailscale does not reach it (AMT is below the OS network stack)
- Remote-AMT-over-VPN deferred — would need a Tailscale subnet router on another always-on host; revisit if it becomes a real need

---

## 7. Nightly cache-warming pipeline

### 7.1 Architecture

```
mini (06:00 Europe/Berlin nightly, RandomizedDelaySec=600)
  ├─ git pull
  ├─ nix flake update                               # mass bump
  ├─ nix build .#nixosConfigurations.{mini,desktop,framework}.config.system.build.toplevel
  ├─ on success: cachix push jadee-flake <result paths>
  │              git commit flake.lock + git push origin main
  ├─ on failure: enter bisect mode (see §7.3)
  └─ journald structured log

desktop / framework / mini
  └─ nix.settings.extra-substituters += "https://jadee-flake.cachix.org"
     nix.settings.extra-trusted-public-keys += "jadee-flake.cachix.org-1:<pubkey>"
```

### 7.2 Decisions

| Aspect | Decision |
|---|---|
| Build targets | three system closures (`mini`, `desktop`, `framework`) — packages are transitive |
| Lockfile policy | nightly `nix flake update`, auto-commit + push on success |
| Branch | `main` only |
| Cache name | `jadee-flake` |
| Cache visibility | public-read |
| Push tool | `cachix push` after build (not `watch-store`) |
| Schedule | 06:00 Europe/Berlin (`OnCalendar=*-*-* 06:00:00`, `RandomizedDelaySec=600`) — accepts that bisect days may overrun into morning; heavy artifacts come from upstream caches |
| Auth token | sops secret `cachix/auth-token`, exposed via `LoadCredential` |
| GC retention | aggressive: `daily` schedule, `--delete-older-than 3d` (mini-only override of `maintenance.garbageCollection.{schedule, deleteOlderThan}`) |
| Self-substitution | mini also configures `jadee-flake.cachix.org` as a substituter — pulls its own freshly-pushed paths on next switch |
| Repo remote | `git@github.com:jadeezomg/flake.git` |
| Push credentials | per-repo SSH **deploy key**, push-only, sops-stored (`mini/git/deploy-key`) |
| Bot identity | commit author `jadee-mini[bot] <bot@jadee.fyi>` |
| Branch protection | none on `main` (bot pushes directly, no PR) |

### 7.3 Bisect-on-failure algorithm

```
1. nix flake update                                 (mass)
2. build all three closures
3. on success → push + commit + done
4. on failure:
   a. git checkout flake.lock                       (reset)
   b. for each input listed in flake.nix:
      - nix flake update <input>                    (advance just that one)
      - build all three closures
      - on success: keep, continue
      - on failure: revert that input's lock entry, record in HELD_BACK, continue
   c. cachix push, git commit + push,
      journal-log HELD_BACK list as a structured warning
```

Failure handling philosophy: **revert only the offending input(s)**, push the
maximal working lockfile. Mini's tree dirty → abort run + journald alert.

Implementation surface: probably a nushell or bash script under `scripts/`,
invoked by a `systemd.services.flake-cache-warm.serviceConfig.ExecStart`,
triggered by a sibling `systemd.timers.flake-cache-warm`.

---

## 8. NixOS misc gating

- `cachix` already in `essentials` profile — no packaging work
- `extra-substituters` / `extra-trusted-public-keys` extended in
  `modules/shared/environment.nix` — adds `jadee-flake.cachix.org` for all
  hosts
- `gc.nix` already provides per-host overridable
  `maintenance.garbageCollection.{schedule, deleteOlderThan}` — mini sets
  `daily` / `3d`
- Stylix/DMS/Niri modules: keep wired in `parts/hosts.nix`; verify inert when
  `desktop.enable = false` during impl

---

## 9. hermes-agent

Source: `github:NousResearch/hermes-agent` — proper flake with `flake.nixosModules.default`, two modes (native systemd / OCI container), config via `services.hermes-agent.{enable, settings, environmentFiles, …}`, supports sops via `environmentFiles`.

### 9.1 Flake wiring

`flake.nix` input:
```nix
hermes-agent = {
  url = "github:NousResearch/hermes-agent";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

`parts/hosts.nix` — add to NixOS modules list:
```nix
inputs.hermes-agent.nixosModules.default
```

### 9.2 Service config

Lives in `hosts/mini/hermes.nix` (new file, imported from `hosts/mini/default.nix`):

```nix
{ config, ... }: {
  services.hermes-agent = {
    enable = true;
    settings = {
      # populated based on hermes config preferences — model, providers, etc.
    };
    environmentFiles = [
      config.sops.secrets."hermes/env".path
    ];
  };
}
```

### 9.3 Mode decision

Native systemd service (default) over OCI container — simpler, fewer moving parts. Container mode adds value only if hermes agents need `apt install` / `pip install` arbitrary tools at runtime; revisit if that becomes a need.

### 9.4 Sops secret

`hermes/env` — environment file format, contains API keys (Anthropic, OpenAI, etc.) hermes-agent needs at runtime. Schema TBD on first run; iterate via `sops secrets/secrets.yaml`.

---

## 10. Profile interaction

Mini opts out manually in `hosts/mini/profiles.nix`:

```nix
{ ... }: {
  dotfiles.profiles = {
    server.enable = true;
    desktop.enable = false;
    integrations.enable = false;
    apps.enable = false;
    devenv.enable = false;
    gaming.enable = false;
    work.enable = false;
  };
}
```

`server.nix` profile body does **not** `mkForce` other profiles off — keeps the steering wheel explicit at the host level. The body of `server.nix` only sets headless-server overrides (kernel switch, firewall, GUI-tool gating).

---

## 11. TODOs (deferred — track here, revisit after stability)

- [ ] **Other services** — concrete enumeration (jellyfin / syncthing / gitea / paperless / nextcloud / etc.). Out of scope for the first install; basics first.
- [ ] **Monitoring** — pick stack (netdata / glances / prometheus + grafana). Requirement: dashboard accessible from desktop/framework/caya browsers. Recommendation when revisiting: **netdata** for low-power, single-host start; migrate to Prometheus/Grafana when scraping multiple hosts becomes a need.
- [ ] **Power tuning** — keep stock for the first install for stability. After validating the box runs reliably, layer in:
  - `powerManagement.cpuFreqGovernor = "powersave"`
  - `services.thermald.enable = true`
  - ASPM enabled in BIOS
  - Verify `intel_pstate=active` (default)
  - `services.logind.lidSwitch = "ignore"` (defensive)
  - No `tlp` (laptop-oriented; conflicts with thermald)
  - Wake-on-LAN: skip (always on)
- [ ] **Backups** — borg / restic / btrbk for btrfs subvols. Off-site target TBD. Not blocking but a real gap.
- [ ] **Storage future** — when adding the second NVMe slot, decide between (a) single btrfs pool with `btrfs device add` (simple, balanced reads, no parity), (b) separate pools per role (build cache / service data / backups), (c) introduce ZFS for snapshots+send/recv (only worth it if RAM is upgraded to ≥32 GB).
- [ ] **Stylix/DMS/Niri inertness** — verify all three modules are no-ops when `desktop.enable = false`. If any leak host activations or system packages, gate their imports on `host.headless or false` in `parts/hosts.nix`.
- [ ] **Tailscale subnet router** — re-enable AMT-over-VPN by adding a subnet router on desktop or framework. Skip until the need arises.
