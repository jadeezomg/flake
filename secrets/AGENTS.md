# SECRETS

## Purpose

Encrypted SOPS/age secret data, schema, and key-management rules.

## Use skills

- `secrets-structure` — secret layout, age key roles, schema updates, and wiring checks.

## Local hazards

- Edit `secrets/secrets.yaml` only with `sops`; never expose secret values in terminal output.
- Update `secrets/SCHEMA.md` whenever a secret key is added, renamed, or repurposed.
- Never commit plaintext `secrets.yaml` or `.flake-host`.
- Do not store SSH login private keys or host age private keys in SOPS.
- `bootstrap-sops-host-key` is first-install only; use rotation commands for existing host keys.
