---
name: secrets-structure
description: Apply this flake's SOPS/age secret layout rules. Use when adding, moving, documenting, or wiring secrets, age recipients, host runtime keys, deploy keys, or session-env API keys.
---

# Secrets Structure

## Scope

Use this for `secrets/`, `.sops.yaml`, secret-consuming Nix modules, and docs that describe secret handling.

## Source files

- `secrets/secrets.yaml`: encrypted SOPS data. Edit only with `sops`.
- `secrets/SCHEMA.md`: canonical schema and consumer map. Update whenever a secret key is added, renamed, or repurposed.
- `.sops.yaml`: age recipient anchors and file creation rules.
- `docs/secrets/`: durable key-management procedures.

## Key model

Keep key roles separate:

- Editor age key: `~/.config/sops/age/keys.txt`, `.sops.yaml` anchor `&editor`.
- NixOS host runtime age keys: `/var/lib/private/sops/age/keys.txt`, anchors like `&framework`, `&desktop`, `&mini`.
- Darwin caya HM/runtime key: `~/.config/sops/age/keys.txt` on caya, anchor `&caya`.
- SSH login private keys stay on clients; never store them in SOPS.
- Host age private keys stay on hosts; never store them in SOPS.
- SSH deploy private keys may live in SOPS only for daemon use, under a host-specific path such as `mini/git/deploy-key`.

## Secret layout

- Flat keys are session-env API keys and are auto-exported to interactive shells by the minimal shell SOPS env layer.
  - Example: `github_token` -> `GITHUB_TOKEN`.
  - Use lower_snake_case.
- Nested keys are explicit Nix-only secrets.
  - Example: `users/jadee/password_framework`.
  - Host-specific values live under `<hostKey>/...` unless the schema already defines a more specific owner.
- Multi-line values use YAML literal blocks (`|`).

## Wiring rule

When adding a secret:

1. Decide flat session-env vs nested explicit Nix secret.
2. Add the value with `sops secrets/secrets.yaml`.
3. Update `secrets/SCHEMA.md` with path, source, consumer, and runtime host.
4. Add or update `sops.secrets."<path>"` in the consuming module for nested secrets.
5. If recipients changed, run `sops updatekeys secrets/secrets.yaml`.

## Safety rules

- Never print secret values in terminal output.
- Never commit plaintext `secrets.yaml` or `.flake-host`.
- Do not weaken permissions to make a service start; fix ownership, mode, or key placement.
- `bootstrap-sops-host-key` is only for first install with an empty host path; rotation uses `rotate-sops-host-key`.

## Checks

- Verify schema docs match the secret path and consuming module.
- Verify the consuming module references the exact nested path.
- For host runtime key changes, use the dedicated `just verify-sops-host-key <host>` flow.
