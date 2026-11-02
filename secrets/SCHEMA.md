# SECRETS SCHEMA

Canonical layout of `secrets/secrets.yaml`. Edit with `sops secrets/secrets.yaml`.

Mini's service secrets (`mini/**`) live in the private `mini-nix` repo
(`secrets/secrets.yaml`, schema in that repo). This file holds everything
shared: user password hashes, session-env keys, matrix/telegram/hermes, wifi.

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

- Every key that `modules/profiles/minimal/security.nix` declares exports to
  the user session env through `modules/profiles/minimal/shells/sops-session-env.nix`
  (`openrouter_api_key` → `OPENROUTER_API_KEY`). Use this form for any secret
  that interactive shells must see. Nesting does not decide export: `kagi/*`
  exports too.
- Other keys (`users/jadee/password_<hostKey>`, `matrix/registration_token`) are
  read only by explicit `sops.secrets.<path>` declarations in Nix modules.
- Multi-line values (SSH keys, env files) use YAML literal block (`|`).
- Anything host-specific lives under `<hostKey>/...`; `mini/**` now lives in
  the private `mini-nix` repo.

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
| `github_token` | https://github.com/settings/tokens (fine-grained, read-only, `public_repo`) | `NIX_CONFIG` access-tokens for flake fetching (not exported as `GITHUB_TOKEN`, so `gh` uses `gh auth`) | all hosts |
| `agent_pat` | GitHub PAT with `repo` + `workflow` scope for AFK agents | shell env `AGENT_PAT`, and mini-nix `services/hermes.nix` → `GITHUB_TOKEN` in hermes env | all hosts |
| `openrouter_api_key` | https://openrouter.ai/keys | shell env `OPENROUTER_API_KEY` | all hosts |
| `context7_api_key` | https://context7.com/dashboard | `ctx7` CLI via env `CONTEXT7_API_KEY` | all hosts |
| `inception_api_key` | (project-specific; document at point of use) | shell env `INCEPTION_API_KEY` | as needed |
| `hf_token` | https://huggingface.co/settings/tokens | shell env `HF_TOKEN` and `HUGGING_FACE_HUB_TOKEN`, mini-nix `secrets.nix` → `mini-llm-hf.env`, and hermes env | all hosts |

> Add new flat keys here in **lower_snake_case**; the session-env layer
> uppercases and underscores them automatically.

### kagi (nested group, rendered into ~/.kagi.toml)

Grouped under a `kagi:` map in `secrets.yaml`. Wired in
`modules/profiles/minimal/security.nix` via explicit `sops.secrets` attrs
(`kagi-api-key`, `kagi-session-token`) that feed the `sops.templates."kagi.toml"`
`[auth]` block. The session-env layer (`sops-session-env.nix`) also exports
them as `KAGI_API_KEY` and `KAGI_SESSION_TOKEN`, because `sessionEnvExcludeAttrs`
is empty. The `kagi` CLI reads env vars before `.kagi.toml`, so the env values
win. On mini, mini-nix `services/hermes.nix` maps `kagi/session_token` into the
hermes env file separately.

| Path | Source | Consumed by | Consumed on |
|---|---|---|---|
| `kagi/api_key` | https://kagi.com/settings/api | `kagi` CLI via `~/.kagi.toml` `[auth] api_key` (sops attr `kagi-api-key`) | all hosts |
| `kagi/session_token` | Kagi session link token (https://kagi.com/settings/user_details) | `kagi` CLI via `~/.kagi.toml` `[auth] session_token`; hermes env on mini | all hosts |

### Home wifi

Shared across every host with a radio, so the path is not host-scoped.
`modules/nixos/home-wifi.nix` applies to hosts where
`dotfiles.hardware.wireless.enable` is true — today framework and mini.

| Path | Source | Consumed by | Consumed on |
|---|---|---|---|
| `wifi/yukikaze_psk` | The wifi pre-shared key of the home FRITZ!Box | `sops.templates."networkmanager-yukikaze.env"` -> `networking.networkmanager.ensureProfiles` in `modules/nixos/home-wifi.nix` | framework, mini |

> Both the SAE and the WPA2 fallback profile read this one key. The access
> point runs WPA2 and WPA3 together, so the two profiles share a password.

### mini host (shared keys used by mini's services)

Mini-only keys (`mini/**`) live in the private `mini-nix` repo; see its
`secrets/SCHEMA.md`. The rows below are keys in this file that mini's
services also read. The `services/...` paths are in mini-nix.

| Path | Source | Consumed by | Consumed on |
|---|---|---|---|
| `cloudflare_dns_api_token` | Cloudflare API token with Zone → DNS → Edit on the `jadee.fyi` zone | `services/caddy.nix` → `caddy.env` `CF_API_TOKEN`, and `scripts/shell/dns-sync.bash` (`mini dns-sync`, runs locally) | mini, workstation |
| `tailscale_authkey` | Reusable, non-ephemeral Tailscale auth key for the Caddy tailnet node | `services/caddy.nix` → `caddy.env` `TS_AUTHKEY` | mini |
| `grafana_secret_key` | Random key. Grafana signs and encrypts its DB data with it. | `services/tracing.nix` → Grafana `security.secret_key` through `$__file{}` (`owner = "grafana"`) | mini |
| `telegram/bot_token` | Telegram bot token for hermes | `services/hermes.nix` → `TELEGRAM_BOT_TOKEN` in hermes env | mini |
| `telegram/allowed_users` | Telegram users that can talk to the hermes bot | `services/hermes.nix` → `TELEGRAM_ALLOWED_USERS` in hermes env | mini |
| `telegram/home_channel` | Telegram home channel for hermes | `services/hermes.nix` → `TELEGRAM_HOME_CHANNEL` in hermes env | mini |
| `matrix/registration_token` | continuwuity registration token (gates account creation) | `services/matrix.nix` → continuwuity `EnvironmentFile` | mini |
| `matrix/hermes_password` | `@hermes` bot account password. **Break-glass only** — used out-of-band to mint the access token / re-bootstrap cross-signing (see `docs/hosts/mini.md § Matrix, Hermes, Caddy`); declared but not put in the hermes env | `services/hermes.nix` | mini |
| `matrix/hermes_access_token` | Long-lived access token for `@hermes` bound to device `hermes-mini` (preferred auth — avoids password re-login key churn that breaks E2EE) | `services/hermes.nix` → `MATRIX_ACCESS_TOKEN` in hermes env | mini |
| `matrix/hermes_recovery_key` | Cross-signing recovery key that verifies the `hermes-mini` device for E2EE; generated during the one-time cross-signing bootstrap | `services/hermes.nix` → `MATRIX_RECOVERY_KEY` in hermes env | mini |

### Future / not yet wired

- `users/<name>/password` for guest users once `passwd` is migrated to sops.
- `cachix/auth-token` and `mini/git/deploy-key`: mini-nix `services/flake-cache-warm.nix`
  declares them, but `module.nix` does not import that file. Neither key is in a
  secrets file today.

## Age & SSH keys

See [docs/secrets/sops-age-keys.md](../docs/secrets/sops-age-keys.md).

- **Editor key** — `~/.config/sops/age/keys.txt` → `&editor`; for `sops secrets/secrets.yaml`
- **Host runtime keys** — NixOS: `/var/lib/private/sops/age/keys.txt`; Darwin: HM path → `&<hostKey>`
- **SSH login** — public keys in `data/users/users.nix`; private keys stay on clients
- **SSH deploy** — private keys in sops for daemons only; mini's are in the private mini-nix repo

## YAML layout (illustrative)

```yaml
# Flat (session-env)
github_token: ghp_xxx
openrouter_api_key: sk-or-xxx
context7_api_key: ctx7sk-xxx

# Nested group, session-env exported (see security.nix)
kagi:
  api_key: xxx
  session_token: xxx

# Per-user, one hash per NixOS host
users:
  jadee:
    password_framework: $6$rounds=...$...

# mini/** is not here: it lives in the mini-nix secrets file.

telegram:
  bot_token: xxx

matrix:
  registration_token: xxx
  hermes_password: xxx
  hermes_access_token: syt_xxx
  hermes_recovery_key: EsT? xxxx xxxx xxxx ...
```

## Adding a new secret — checklist

1. Decide session-env (declared in `security.nix`) vs Nix-only. See conventions.
2. `sops secrets/secrets.yaml` → add the key with value.
3. If Nix-only, declare it in the consuming module:
   ```nix
   sops.secrets."<path>" = { mode = "0400"; };
   config.sops.secrets."<path>".path  # the file path at runtime
   ```
4. Add a row to this file.
5. After any change to recipients (`.sops.yaml`): `sops updatekeys secrets/secrets.yaml`.
