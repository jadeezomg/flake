# SECRETS

Encrypted with `sops` + `age`. Keys in `~/.config/sops/age/keys.txt`.

## Usage

```bash
sops secrets/secrets.yaml             # decrypt → edit → re-encrypt on save
sops updatekeys secrets/secrets.yaml  # after editing .sops.yaml recipients
```

## Session Env Export

Secrets auto-export to the user session env via `home/shared/shells/sops-session-env.nix`:
- Attr `foo-bar` → env var `FOO_BAR`
- `github-token` → also sets `GITHUB_PAT`, `GITHUB_PERSONAL_ACCESS_TOKEN`, `NIX_CONFIG` access-tokens
- Linux: writes `~/.config/environment.d/50-sops-secrets.conf` + `systemctl --user set-environment`
- Darwin: LaunchAgent runs `launchctl setenv` at login (and during activation)

Picked up by every shell launched after activation (PAM session on Linux, launchd-spawned terminals on Darwin). Already-running processes need a restart.

## Gotchas

- Never commit `secrets.yaml` unencrypted or `.flake-host`
- After adding a new age key recipient, always run `sops updatekeys secrets/secrets.yaml`
