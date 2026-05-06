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

All edits committed before booting the mini. Mini will `git clone` this on
first install, so anything missing here means manual scp during install.

### 1.1 Add flake inputs

Edit `flake.nix`:

```nix
inputs = {
  # ...existing...

  disko = {
    url = "github:nix-community/disko";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  hermes-agent = {
    url = "github:NousResearch/hermes-agent";
    inputs.nixpkgs.follows = "nixpkgs";
  };
};
```

### 1.2 Wire modules in `parts/hosts.nix`

Add to the NixOS `modules = [ ... ]` list (Linux-only path):

```nix
inputs.disko.nixosModules.disko
inputs.hermes-agent.nixosModules.default
```

### 1.3 Refactor `modules/nixos/boot.nix`

Gate plymouth + kernel choice behind `server.enable`:

```nix
{ pkgs, lib, config, ... }:
let serverProfile = config.dotfiles.profiles.server.enable;
in {
  boot = {
    loader.systemd-boot.enable = lib.mkForce false;
    loader.efi = {
      canTouchEfiVariables = true;
      efiSysMountPoint = "/boot";
    };

    kernelPackages =
      if serverProfile && pkgs ? cachyosKernels
      then pkgs.cachyosKernels.linuxPackages-cachyos-server
      else if pkgs ? cachyosKernels
      then pkgs.cachyosKernels.linuxPackages-cachyos-latest-zen4
      else pkgs.linuxPackages_latest;

    lanzaboote = {
      enable = true;
      pkiBundle = "/var/lib/sbctl";
    };

    plymouth = lib.mkIf (!serverProfile) {
      enable = true;
      theme = lib.mkForce "blahaj";
      themePackages = [ pkgs.plymouth-blahaj-theme ];
    };
  };
}
```

### 1.4 Refactor `modules/nixos/networking.nix`

Split GUI tools out, replace firewalld with NixOS firewall when
`server.enable`:

```nix
{ host, pkgs, lib, config, ... }:
let serverProfile = config.dotfiles.profiles.server.enable;
in {
  networking.hostName = host.hostname or "nixos";
  networking.networkmanager.enable = true;

  services.tailscale = {
    enable = true;
    openFirewall = true;
    extraUpFlags = [ "--ssh" ];
  };

  networking.firewall = lib.mkIf serverProfile {
    enable = true;
    allowedTCPPorts = [ 22 ];
    trustedInterfaces = [ "tailscale0" ];
  };

  environment.systemPackages = with pkgs; (
    [ networkmanager openresolv wirelesstools nfs-utils samba tailscale wireguard-tools ]
    ++ lib.optionals (!serverProfile) [
      networkmanagerapplet
      firewalld
      firewalld-gui
      proton-vpn
      wireguard-ui
    ]
  );
}
```

### 1.5 Repurpose `modules/shared/profiles/server.nix`

Body becomes empty (or minimal); server-mode behaviour is gated inline in
boot/networking via `config.dotfiles.profiles.server.enable`. Remove the
postgres+redis lines (they were placeholders that were never used).

```nix
{ ... }: {
  # Headless-server overrides are gated inline in modules/nixos/{boot,networking}.nix
  # via config.dotfiles.profiles.server.enable. This profile body is intentionally
  # minimal — toggles, not packages.
}
```

### 1.6 Extend `data/users/users.nix` — shared SSH keys

Add `sshKeys` field to the `jadee` user record:

```nix
jadee = {
  username = "jadee";
  # ...existing...
  sshKeys = [
    "ssh-ed25519 AAAA... jadee@desktop"
    "ssh-ed25519 AAAA... jadee@framework"
    "ssh-ed25519 AAAA... jadee@caya"
  ];
};
```

Update `modules/nixos/user.nix` to consume it:

```nix
users.users.${user} = {
  # ...existing...
  openssh.authorizedKeys.keys = userConfig.sshKeys or [];
};
```

(Get the actual public keys: `cat ~/.ssh/id_ed25519.pub` on each existing host.)

### 1.7 Sops password+token scaffolding

Generate a placeholder hashed password and add four secrets to
`secrets/secrets.yaml` using `sops`:

```bash
# Generate hashed password (interactive)
mkpasswd -m sha-512

# Edit secrets file
sops secrets/secrets.yaml
```

Add (don't commit values until later when mini has its key):

```yaml
users:
  jadee:
    password: "$6$..."          # mkpasswd output
cachix:
  auth-token: ""                # filled in §6
mini:
  git:
    deploy-key: |               # filled in §6
      -----BEGIN OPENSSH PRIVATE KEY-----
      ...
      -----END OPENSSH PRIVATE KEY-----
  amt:
    password: ""                # filled in §3
hermes:
  env: |                        # filled in later
    ANTHROPIC_API_KEY=
    OPENAI_API_KEY=
```

Mini's age key recipient is added in §5.4 — secrets stay encrypted-without-mini
until then. That's fine; `nixos-install` doesn't need them yet.

### 1.8 Create `hosts/mini/` files

```
hosts/mini/
  host.nix            # facts (see below)
  profiles.nix        # toggle list (see below)
  default.nix         # imports + hermes service
  hardware-configuration.nix   # minimal — kernel modules only
  disko.nix           # partition schema (see mini.md §4.1)
  hermes.nix          # services.hermes-agent config
  flake-cache-warm.nix # systemd timer + service for nightly bot (see §6)
```

Register in `hosts/hosts.nix`:

```nix
{
  hosts = {
    framework = import ./framework/host.nix;
    desktop = import ./desktop/host.nix;
    caya = import ./caya/host.nix;
    mini = import ./mini/host.nix;
  };
}
```

`hosts/mini/host.nix`:

```nix
let
  inherit (import ../lib.nix) sharedNixOSHost sharedNixOSUser;
in
  sharedNixOSHost
  // {
    hostname = "mini";
    description = "Mini — Minisforum MS-01 headless server";
    user = sharedNixOSUser;
    extraUsers = [];                     # no guest accounts on a server
    buildCores = 12;                     # i5-12600H — 16 threads, leave 4 for daemon/ssh/hermes
    stateVersion = "25.11";
  }
```

Note: `mainMonitor`, `dmsSettingsFile`, `niriOutputsFile` deliberately omitted
— consumers must `host.mainMonitor or null` guard. Verify during impl that
no module hard-references these without a guard.

`hosts/mini/profiles.nix`: see `mini.md` §10.

`hosts/mini/default.nix`:

```nix
{ ... }: {
  imports = [
    ./hardware-configuration.nix
    ./disko.nix
    ../../modules/shared
    ../../modules/nixos
    ./profiles.nix
    ./hermes.nix
    ./flake-cache-warm.nix
  ];

  # NOPASSWD wheel — mini-only quality-of-life over SSH
  security.sudo.wheelNeedsPassword = false;

  # Aggressive GC for cache-warming host
  maintenance.garbageCollection = {
    schedule = "daily";
    deleteOlderThan = "3d";
  };

  # Static IP on the 2.5G NIC
  networking.networkmanager.ensureProfiles.profiles."mini-lan" = {
    connection = {
      id = "mini-lan";
      type = "ethernet";
      interface-name = "enp2s0f0";   # adjust after first boot if naming differs
      autoconnect = true;
    };
    ipv4 = {
      method = "manual";
      address1 = "192.168.X.Y/24,192.168.X.1";    # fill in
      dns = "1.1.1.1;9.9.9.9";
    };
    ipv6.method = "auto";
  };

  # Swap via zram
  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };

  # AMT — non-root /dev/mei access
  users.groups.amt = {};
  services.udev.extraRules = ''
    KERNEL=="mei*", GROUP="amt", MODE="0660"
  '';
  users.users.jadee.extraGroups = [ "amt" ];

  environment.systemPackages = with pkgs; [
    amtterm
    openwsman
  ];

  services.fwupd.enable = true;

  # SSH config
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      AllowUsers = [ "jadee" ];
    };
  };

  # Sops secret for jadee password (declarative, replaces manual passwd)
  sops.secrets."users/jadee/password".neededForUsers = true;
  users.users.jadee.hashedPasswordFile = config.sops.secrets."users/jadee/password".path;

  system.stateVersion = "25.11";
}
```

`hosts/mini/hermes.nix`: see `mini.md` §9.2.

`hosts/mini/flake-cache-warm.nix`: see §6 below.

### 1.9 Add cachix substituter for all hosts

Edit `modules/shared/environment.nix` — append to the existing
`extra-substituters` and `extra-trusted-public-keys`:

```nix
extra-substituters = [
  # ...existing...
  "https://jadee-flake.cachix.org"
];
extra-trusted-public-keys = [
  # ...existing...
  "jadee-flake.cachix.org-1:<pubkey-from-§6.1>"   # fill in after creating cache
];
```

### 1.10 Format + commit

```bash
just fmt
git add hosts/mini hosts/hosts.nix data/users/users.nix \
        modules/nixos/{boot,networking,user}.nix \
        modules/shared/{environment.nix,profiles/server.nix} \
        flake.nix flake.lock \
        parts/hosts.nix \
        secrets/secrets.yaml \
        docs/hosts/
git commit -m "feat(hosts): add mini headless server scaffolding"
git push origin main
```

The flake is self-consistent at this point. desktop/framework can keep
running unchanged (they don't get `server.enable = true`).

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

## 6. Cache-warming pipeline — first run

### 6.1 Create the cachix cache

On workstation:

```bash
cachix authtoken <your-personal-token>      # one-time
cachix create jadee-flake                   # creates the cache, public read by default
cachix use jadee-flake                       # prints the public key
```

Copy the printed `jadee-flake.cachix.org-1:<pubkey>=` into
`modules/shared/environment.nix` (§1.9 placeholder), commit, push.

Generate a **push-only** auth token for the bot:

```bash
cachix authtoken --create-token --scope push --cache jadee-flake
# → token-xxx...
```

Sops-encrypt:

```bash
sops secrets/secrets.yaml      # set cachix.auth-token = "token-xxx..."
git add secrets/secrets.yaml
git commit -m "feat(secrets): add cachix push token"
git push
```

### 6.2 Generate the deploy key on mini

```bash
# On mini
ssh-keygen -t ed25519 -N '' -C 'mini@flake-bot' -f /tmp/mini-deploy-key
cat /tmp/mini-deploy-key.pub
# → copy this for the next step
```

GitHub UI → `jadeezomg/flake` → Settings → Deploy keys → Add deploy key:
- Title: `mini-bot`
- Key: paste the public key
- ✅ Allow write access
- Save

Sops-encrypt the private key:

```bash
# On workstation
ssh jadee@mini cat /tmp/mini-deploy-key
# Paste content into secrets.yaml under mini.git.deploy-key (multiline)
sops secrets/secrets.yaml
git commit + push
ssh jadee@mini rm /tmp/mini-deploy-key /tmp/mini-deploy-key.pub
```

Add to `flake-cache-warm.nix` on mini (sketch):

```nix
{ config, pkgs, lib, ... }:
let
  cacheWarm = pkgs.writeShellApplication {
    name = "flake-cache-warm";
    runtimeInputs = with pkgs; [ git nix cachix coreutils openssh jq ];
    text = ''
      set -euo pipefail
      REPO=/var/lib/flake-cache-warm/flake
      CACHIX_NAME=jadee-flake

      # Setup git identity + ssh
      export GIT_SSH_COMMAND="ssh -i $CREDENTIALS_DIRECTORY/deploy-key -o StrictHostKeyChecking=accept-new"
      git config --global user.email "bot@jadee.fyi"
      git config --global user.name  "jadee-mini[bot]"

      mkdir -p "$(dirname "$REPO")"
      if [ ! -d "$REPO" ]; then
        git clone git@github.com:jadeezomg/flake.git "$REPO"
      fi
      cd "$REPO"
      git fetch origin main
      git reset --hard origin/main

      # Mass update
      nix flake update

      build_all() {
        nix build --no-link \
          .#nixosConfigurations.mini.config.system.build.toplevel \
          .#nixosConfigurations.desktop.config.system.build.toplevel \
          .#nixosConfigurations.framework.config.system.build.toplevel
      }

      if build_all; then
        echo "mass build OK"
      else
        echo "mass build failed; entering bisect"
        git checkout flake.lock
        HELD_BACK=()
        # iterate through flake inputs; per-input update + retry (see mini.md §7.3)
        for input in $(nix flake metadata --json | jq -r '.locks.nodes.root.inputs | keys[]'); do
          nix flake update "$input"
          if build_all; then
            echo "input $input: kept"
          else
            echo "input $input: held back"
            git checkout flake.lock
            nix flake update --override-input "$input" "$(nix flake metadata --json | jq -r ".locks.nodes.\"$input\".original | tojson")"
            HELD_BACK+=("$input")
          fi
        done
        echo "Held back: ''${HELD_BACK[*]}"
      fi

      # Push paths to cachix
      export CACHIX_AUTH_TOKEN=$(cat "$CREDENTIALS_DIRECTORY/cachix-token")
      nix path-info --json --closure-size \
        .#nixosConfigurations.mini.config.system.build.toplevel \
        .#nixosConfigurations.desktop.config.system.build.toplevel \
        .#nixosConfigurations.framework.config.system.build.toplevel \
        | jq -r 'to_entries[].key' \
        | cachix push "$CACHIX_NAME"

      # Commit + push if lockfile changed
      if ! git diff --quiet flake.lock; then
        git add flake.lock
        git commit -m "chore(flake): nightly lockfile bump ($(date -I))"
        git push origin main
      fi
    '';
  };
in {
  systemd.services.flake-cache-warm = {
    description = "Nightly flake update + build + cachix push";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${cacheWarm}/bin/flake-cache-warm";
      LoadCredential = [
        "deploy-key:${config.sops.secrets."mini/git/deploy-key".path}"
        "cachix-token:${config.sops.secrets."cachix/auth-token".path}"
      ];
      User = "root";   # need to read sops secrets + write into /var/lib/flake-cache-warm
    };
  };

  systemd.timers.flake-cache-warm = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 06:00:00";
      RandomizedDelaySec = "10m";
      Persistent = true;
    };
  };

  sops.secrets."mini/git/deploy-key" = { mode = "0400"; };
  sops.secrets."cachix/auth-token" = { mode = "0400"; };
}
```

(Bisect block above is a sketch — refine the `--override-input` revert logic
during impl. The lock-file revert via `git checkout flake.lock` per-input is
the working approach.)

### 6.3 First manual run

```bash
ssh jadee@mini
sudo systemctl start flake-cache-warm.service
journalctl -fu flake-cache-warm.service
```

Expected: clones repo, runs `nix flake update`, builds three closures (mostly
cache-hits from upstream caches), pushes new paths to `jadee-flake.cachix.org`,
commits + pushes lockfile bump to `main`.

### 6.4 Verify other hosts pull from the new cache

```bash
# On desktop
git pull
just switch       # should show "copying path '/nix/store/...' from 'https://jadee-flake.cachix.org'"
```

If you see the cachix URL in the output, the pipeline is end-to-end working.

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
| `systemctl list-timers flake-cache-warm.timer` | scheduled for 06:00 |
| `systemctl status hermes-agent.service` | `active (running)` |
| `nix store info --store https://jadee-flake.cachix.org` | reachable |
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
