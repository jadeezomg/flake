# SECRETS SCHEMA

Canonical layout of `secrets/secrets.yaml`. Edit with `sops secrets/secrets.yaml`.

Every entry below lists:
- **Path** — the YAML key (slash-separated for nested attrs)
- **Source** — how to generate / obtain the value
- **Consumed by** — Nix path(s) that read it
- **Consumed on** — which host(s) mount/use the secret at runtime (organizational)

## Encryption scope

> **All secrets** in `secrets/secrets.yaml` are encrypted to **every** recipient in
> `.sops.yaml` (`&editor`, `&framework`, `&desktop`, `&caya`, `&mini` when listed).
> Any host with a valid runtime private key can decrypt the full file. The
> **Consumed on** column is which host reads the value — not who can decrypt it.

## Conventions

- Flat keys (`github_token`) auto-export to the user session env as
  `GITHUB_TOKEN` via `home/shared/shells/sops-session-env.nix`. Use this form
  for any secret that needs to be visible to interactive shells.
- Nested paths (`users/jadee/password_<hostKey>`, `mini/git/deploy-key`) are
  referenced explicitly by `sops.secrets.<path>` declarations in Nix modules
  and are *not* exported to the env.
- Multi-line values (SSH keys, env files) use YAML literal block (`|`).
- Anything host-specific lives under `<hostKey>/...`.

## Schema

### User auth

One entry per NixOS host — `modules/nixos/user.nix` maps `hostKey` to the
corresponding secret. Picking distinct hashes per host means rotating one
host doesn't invalidate the others' `/etc/shadow` on next switch.

| Path | Source | Consumed by | Consumed on |
|---|---|---|---|
| `users/jadee/password_desktop` | `mkpasswd -m sha-512` | `users.users.jadee.hashedPasswordFile` on desktop | desktop |
| `users/jadee/password_framework` | `mkpasswd -m sha-512` | `users.users.jadee.hashedPasswordFile` on framework | framework |
| `users/jadee/password_mini` | `mkpasswd -m sha-512` | `users.users.jadee.hashedPasswordFile` on mini (post-bootstrap) | mini |

> **Always paste the `$6$rounds=...$...` output of `mkpasswd`, never the
> plaintext.** sops happily encrypts whatever string you save; if it isn't a
> crypt hash, NixOS still writes it verbatim to `/etc/shadow` and login will
> reject every password you type.

### Session-env API keys (flat keys, auto-exported)

| Path | Source | Consumed by | Consumed on |
|---|---|---|---|
| `github_token` | https://github.com/settings/tokens — fine-grained, read-only, `public_repo` | shell env `GITHUB_TOKEN` / `GITHUB_PAT`, plus `NIX_CONFIG` access-tokens for flake fetching | all hosts |
| `agent_pat` | GitHub PAT with `repo` + `workflow` scope for AFK agents | shell env `AGENT_PAT` | desktop, framework, caya |
| `openrouter_api_key` | https://openrouter.ai/keys | shell env `OPENROUTER_API_KEY` | all hosts |
| `kagi_api_key` | https://kagi.com/settings/api | `kagi-ken-cli` via env `KAGI_API_KEY` | all hosts |
| `context7_api_key` | https://context7.com/dashboard | `ctx7` CLI via env `CONTEXT7_API_KEY` | all hosts |
| `inception_api_key` | (project-specific; document at point of use) | shell env `INCEPTION_API_KEY` | as needed |

> Add new flat keys here in **lower_snake_case**; the session-env layer
> uppercases and underscores them automatically.

### mini host

| Path | Source | Consumed by | Consumed on |
|---|---|---|---|
| `mini/amt/password` | the MEBx password set in `docs/hosts/mini-install.md` §3 | **reference only** — not consumed declaratively; stored for recovery | (reference) |
| `mini/git/deploy-key` | `ssh-keygen -t ed25519 -N '' -C 'mini@flake-bot'` on mini; register `.pub` as a deploy key with write access on `github.com/jadeezomg/flake`. Paste the **private** key here. | `hosts/mini/flake-cache-warm.nix` → `systemd LoadCredential` → `GIT_SSH_COMMAND` | mini |
| `cachix/auth-token` | `cachix authtoken --create-token --scope push --cache jadee-flake` | `hosts/mini/flake-cache-warm.nix` → `cachix push` | mini |
| `hermes/env` | API keys + provider creds for `services.hermes-agent`. Format: multi-line `KEY=value`. Schema TBD on first hermes run. | `hosts/mini/hermes.nix` → `services.hermes-agent.environmentFiles` (currently optional) | mini |

### Future / not yet wired

- `users/<name>/password` for guest users once `passwd` is migrated to sops.

## Age & SSH keys

See [docs/secrets/sops-age-keys.md](../docs/secrets/sops-age-keys.md).

- **Editor key** — `~/.config/sops/age/keys.txt` → `&editor`; for `sops secrets/secrets.yaml`
- **Host runtime keys** — NixOS: `/var/lib/private/sops/age/keys.txt`; Darwin: HM path → `&<hostKey>`
- **SSH login** — public keys in `data/users/users.nix`; private keys stay on clients
- **SSH deploy** — private keys in sops (e.g. `mini/git/deploy-key`) for daemons only

## YAML layout (illustrative)

```yaml
# Flat (session-env)
github_token: ghp_xxx
openrouter_api_key: sk-or-xxx
kagi_api_key: xxx
context7_api_key: ctx7sk-xxx

# Per-user
users:
  jadee:
    password: $6$rounds=...$...

# Per-host
mini:
  amt:
    password: <MEBx password>
  git:
    deploy-key: |
      -----BEGIN OPENSSH PRIVATE KEY-----
      ...
      -----END OPENSSH PRIVATE KEY-----

cachix:
  auth-token: eyJ...

hermes:
  env: |
    ANTHROPIC_API_KEY=sk-ant-...
    OPENAI_API_KEY=sk-...
```

## Adding a new secret — checklist

1. Decide flat (session-env) vs nested (Nix-only). See conventions.
2. `sops secrets/secrets.yaml` → add the key with value.
3. If nested, declare it in the consuming module:
   ```nix
   sops.secrets."<path>" = { mode = "0400"; };
   config.sops.secrets."<path>".path  # the file path at runtime
   ```
4. If nested, declare it in the consuming module (see examples in this file).
5. After any change to recipients (`.sops.yaml`): `sops updatekeys secrets/secrets.yaml`.
