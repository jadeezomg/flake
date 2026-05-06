# SECRETS

Encrypted with `sops` + `age`. Keys in `~/.config/sops/age/keys.txt`.

## Usage

```bash
sops secrets/secrets.yaml             # decrypt → edit → re-encrypt on save
sops updatekeys secrets/secrets.yaml  # after editing .sops.yaml recipients
```

## Shell Export

Secrets auto-export to interactive shells via `home/shared/shells/sops-shell-secrets.nix`:
- Attr `foo-bar` → env var `FOO_BAR`
- `github-token` → also sets `GITHUB_PAT`, `GITHUB_PERSONAL_ACCESS_TOKEN`, `NIX_CONFIG` access-tokens

## Gotchas

- Never commit `secrets.yaml` unencrypted or `.flake-host`
- After adding a new age key recipient, always run `sops updatekeys secrets/secrets.yaml`
