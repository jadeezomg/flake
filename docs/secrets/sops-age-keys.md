# Sops age keys

Reference for age/sops key management in this flake. SSH login/destinations: [Appendix A](#appendix-a-ssh-login--destinations).

**Quick links**

| Task | Command |
|------|---------|
| Edit secrets | `sops secrets/secrets.yaml` |
| Create editor key | `just setup-age-editor` |
| Caya HM/runtime age key | `just setup-age-darwin` |
| First install host key (empty path only) | `just bootstrap-sops-host-key` |
| Unblock switch (temporary) | `just bootstrap-sops-host-key-from-editor` |
| **Dedicated host key (after Phase 1)** | **`just rotate-sops-host-key`** |
| Verify host key | `just verify-sops-host-key framework` |
| After `.sops.yaml` changes | `sops updatekeys secrets/secrets.yaml` |

See also: [SCHEMA.md](./SCHEMA.md).

---

## Encryption model

> **Current model:** one shared recipient set for the whole `secrets/secrets.yaml`.
> Every listed anchor (`&editor`, `&framework`, `&desktop`, `&caya`, `&mini`) can
> decrypt **every** secret. Paths like `users/jadee/password_desktop` or
> `mini/git/deploy-key` are **organizational only** — not cryptographic isolation.
>
> Any host with a valid runtime private key can read all secrets. Tighter
> per-path `creation_rules` are possible later but not used today.

---

## Architecture

```text
┌─────────────────────────────────────────────────────────────────┐
│  Age editor key          sops secrets/secrets.yaml              │
│  Private: ~/.config/sops/age/keys.txt   Public: &editor        │
├─────────────────────────────────────────────────────────────────┤
│  Age host keys           NixOS switch decrypts passwords        │
│  Private: /var/lib/private/sops/age/keys.txt                    │
│  Public: &framework, &desktop, &mini in .sops.yaml              │
├─────────────────────────────────────────────────────────────────┤
│  Darwin runtime          HM sops on caya only                   │
│  Private: ~/.config/sops/age/keys.txt   Public: &caya           │
└─────────────────────────────────────────────────────────────────┘
```

**Do not store in sops:** SSH host keys, SSH login private keys, age host private keys.

---

## Recipients in `.sops.yaml`

| Anchor | Role | Private key location |
|--------|------|-------------------|
| `&editor` | Human edits secrets | `~/.config/sops/age/keys.txt` |
| `&framework` | Framework runtime | `/var/lib/private/sops/age/keys.txt` |
| `&desktop` | Desktop runtime | same path on desktop |
| `&mini` | Mini runtime | same path on mini |
| `&caya` | Caya HM/runtime | `~/.config/sops/age/keys.txt` on macOS |

---

## Phase 0 — Prerequisites (once per dev machine)

```bash
cd ~/.dotfiles/flake

# 1. Editor key (skip if ~/.config/sops/age/keys.txt already exists)
just setup-age-editor

# 2. Verify pubkey matches &editor in .sops.yaml
nix develop . --command age-keygen -y ~/.config/sops/age/keys.txt
grep '&editor' .sops.yaml
```

### Editor pubkey mismatch

If the printed pubkey **does not** match `&editor` in `.sops.yaml`:

- **Do not** run `setup-age-editor` again — it skips when the file already exists.
- **Restore** the private key that matches `&editor` from backup / password manager, **or**
- **Rotate** `&editor` from a machine that still holds *any* recipient private key that can decrypt `secrets/secrets.yaml`, then run `sops updatekeys secrets/secrets.yaml`.

If the old editor private key is lost **and** no other recipient private key remains, secrets are **unrecoverable**.

---

## Phase 1 — Unblock NixOS switch (temporary)

Use when `flake switch` fails: missing `/var/lib/private/sops/age/keys.txt` or decrypt errors while `&framework` still equals `&editor`.

```bash
cd ~/.dotfiles/flake
git pull

just bootstrap-sops-host-key-from-editor   # fails if host key already exists
sops updatekeys secrets/secrets.yaml       # if .sops.yaml changed
flake switch
```

This copies the **editor** private key to the host path. It is **not** a dedicated host key. Proceed to Phase 2 before considering the host done.

---

## Phase 2 — Dedicated host key (required after Phase 1)

**Do not use `bootstrap-sops-host-key` for rotation** — it refuses to run when
`/var/lib/private/sops/age/keys.txt` already exists.

### Step 2.1 Rotate on the NixOS host

```bash
cd ~/.dotfiles/flake
just rotate-sops-host-key
```

This backs up the old key, generates a **new** dedicated host key, and prints the pubkey.

### Step 2.2 Update `.sops.yaml` (workstation)

Replace `&<hostKey>` with the **new** pubkey (must differ from `&editor`):

```yaml
  - &framework age1NEW_FROM_ROTATE   # not the same as &editor
```

For mini's first dedicated key (fresh install, not Phase 1 copy), use
`just bootstrap-sops-host-key` instead — only when the host path is empty.

### Step 2.3 Rekey and commit **before** switch on that host

```bash
sops updatekeys secrets/secrets.yaml
git add .sops.yaml secrets/secrets.yaml
git commit -m "feat(secrets): rotate <hostKey> host age recipient"
git push
```

### Step 2.4 Verify on the NixOS host

```bash
git pull
just verify-sops-host-key framework   # or desktop / mini
```

Must pass: host pubkey matches `&<hostKey>`, differs from editor, yaml anchors differ.

### Step 2.5 Switch

```bash
flake switch
```

### Step 2.6 Backup

Store the new `/var/lib/private/sops/age/keys.txt` and the `.bak.*` file offline. Never commit them.

---

## Phase 3 — Caya (Darwin)

No system-level sops — home-manager only. Caya uses one age key for HM runtime decryption (`&caya`).

```bash
just setup-age-darwin    # creates ~/.config/sops/age/keys.txt if missing
age-keygen -y ~/.config/sops/age/keys.txt   # must match &caya
```

If caya is also a secret-editing machine, that same file is the editor key — ensure `&editor` and `&caya` both list the pubkey (or use separate keys and two yaml anchors).

---

## Phase 4 — Mini first install

`bootstrap = true` in `hosts/mini/default.nix` skips sops password until the host age key exists at `/var/lib/private/sops/age/keys.txt`.

### 4.1 Install with bootstrap

```bash
sudo nixos-install --flake .#mini --no-root-password
```

`initialPassword = "changeme"`; sops password not declared.

### 4.2 Bootstrap host age key on mini

```bash
ssh jadee@192.168.1.10
cd ~/.dotfiles/flake
just bootstrap-sops-host-key    # only when host path is empty
```

### 4.3 Workstation: mini recipient + password hash

**Blocking checklist — complete all before §4.4:**

- [ ] `users/jadee/password_mini` exists in `secrets/secrets.yaml` (`mkpasswd -m sha-512` hash, not plaintext)
- [ ] `&mini` uncommented in `.sops.yaml` with pubkey from step 4.2
- [ ] `- *mini` added under `creation_rules`
- [ ] `sops updatekeys secrets/secrets.yaml` run locally
- [ ] `.sops.yaml` and `secrets/secrets.yaml` committed and pushed

```bash
# Workstation
mkpasswd -m sha-512
sops secrets/secrets.yaml          # add users.jadee.password_mini

# Edit .sops.yaml → &mini age1...
sops updatekeys secrets/secrets.yaml
git add .sops.yaml secrets/secrets.yaml
git commit -m "feat(secrets): add mini recipient and password_mini"
git push
```

### 4.4 Exit bootstrap (only after §4.3 checklist)

```bash
# Workstation: hosts/mini/default.nix → bootstrap = false
git commit -am "feat(mini): exit sops bootstrap"
git push

# On mini
git pull
just verify-sops-host-key mini
just init
flake switch
```

---

## Phase 5 — User passwords in sops

```bash
mkpasswd -m sha-512
sops secrets/secrets.yaml
# users.jadee.password_<hostKey>: "<hash>"
```

Consumed by `modules/nixos/user.nix` → `hashedPasswordFile`.

---

## Troubleshooting

| Error | Fix |
|-------|-----|
| `Cannot read ssh key … ssh_host_ed25519_key` | Pull latest flake; model uses `age.keyFile`, not `sshKeyPaths` |
| `failed to decrypt … 0 successful groups` | Missing host key file or pubkey not in `.sops.yaml` |
| `bootstrap-sops-host-key` exits 1 (exists) | Use `rotate-sops-host-key` or `verify-sops-host-key` |
| Host key equals editor after "Phase 2" | You ran bootstrap, not rotate — run `just rotate-sops-host-key` |
| `sops updatekeys` fails | Need a working recipient private key (editor or any host) |
| Editor pubkey mismatch | See [Editor pubkey mismatch](#editor-pubkey-mismatch) — not "setup again" |

---

## Checklist (all hosts aligned)

- [ ] `&editor` set; editor key backed up
- [ ] Framework: Phase 1 (if needed) → **`rotate-sops-host-key`** → verify → switch
- [ ] Desktop: dedicated host key + verify
- [ ] Mini: §4.3 checklist complete → `bootstrap = false`
- [ ] Caya: `&caya` matches HM key
- [ ] `sops updatekeys` after every recipient change
- [ ] Host private keys backed up outside git
- [ ] `flake switch` succeeds on all NixOS hosts

---

## Appendix A — SSH login & destinations

Separate from sops/age. Documented here for convenience.

**Login (into NixOS hosts):** public key in `data/users/users.nix` → `modules/nixos/openssh.nix`.

**Client aliases:** `data/network/ssh-destinations.nix` → `ssh framework`, `ssh unraid`, etc.

**Unraid:** enable SSH in UI; add login pubkey to `/root/.ssh/authorized_keys`.

See `data/network/ssh-destinations.nix` for IPs/hostnames.
