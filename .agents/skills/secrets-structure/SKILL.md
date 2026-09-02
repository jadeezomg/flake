---
name: secrets-structure
description: Apply this flake's SOPS/age secret layout rules. Use when adding, moving, documenting, or wiring secrets, age recipients, host runtime keys, deploy keys, session-env API keys, sops templates, or keyring delivery.
---

# Secrets Structure

## Scope

Use this for `secrets/`, `.sops.yaml`, secret-consuming Nix modules, `Justfile` secret recipes, and docs that describe secret handling.

## Source files

- `secrets/secrets.yaml`: encrypted SOPS data. Edit only with `sops` or `just secret-set`.
- `secrets/SCHEMA.md`: canonical schema. It must list every key that Nix references. Update it with every key change.
- `.sops.yaml`: age recipient anchors and one creation rule.
- `docs/secrets/`: key-management procedures (`sops-age-keys.md`, `per-host-and-pass-plan.md`).
- `lib/default.nix`: `sopsFile` points at `secrets/secrets.yaml` for all modules.

## Key model

- Editor age key: `~/.config/sops/age/keys.txt`, anchor `&editor`. Create it with `just setup-age-editor`.
- NixOS host runtime keys: `/var/lib/private/sops/age/keys.txt`, anchors `&framework`, `&desktop`, `&mini`. Set in `modules/nixos/sops.nix`.
- Darwin (`caya`): anchor `&caya`. There is no Darwin system-level sops config. The key path `~/.config/sops/age/keys.txt` comes from the shared HM module `modules/profiles/minimal/security.nix`, which applies on all hosts. `just setup-age-darwin` creates it.
- SSH login private keys stay on clients. Host age private keys stay on hosts. Never store either in SOPS.
- SSH deploy private keys can live in SOPS for daemon use only. Current examples: `mini/git/deploy-key` (`hosts/mini/flake-cache-warm.nix`) and `mini/backup/unraid-ssh-key` (`hosts/mini/services/immich-backup.nix`). Public halves are not stored.
- The `.sops.yaml` `path_regex` matches only files directly in `secrets/`. A file in a subdirectory gets no recipients.
- Every recipient can decrypt the whole file. The schema's "Consumed on" column says who reads a value, not who can decrypt it.

## Secret layout

- Use lower_snake_case for YAML keys. Host-specific values live under `<hostKey>/...`.
- Multi-line values use YAML literal blocks (`|`).
- User password hashes live at `users/jadee/password_<hostKey>`. `modules/nixos/user.nix` maps `hostKey` to that path.
- Nesting in YAML does not decide export. The wiring form (below) decides it.

## Wiring forms

1. HM session-env secret. Declare `sops.secrets."<attr>" = { key = "<yaml/path>"; path = ...; }` in `security.nix`. `sops-session-env.nix` exports every attribute declared there. The variable name is the attribute in upper case, dashes to underscores (`openrouter-api-key` -> `OPENROUTER_API_KEY`). `sessionEnvExcludeAttrs` is empty, so `kagi-api-key` and `kagi-session-token` (from nested `kagi/*`) export as `KAGI_API_KEY` and `KAGI_SESSION_TOKEN`. Fan-outs: `github-token` -> `GITHUB_TOKEN`, `GITHUB_PAT`, `GITHUB_PERSONAL_ACCESS_TOKEN`, `NIX_CONFIG`; `hf-token` -> `HF_TOKEN`, `HUGGING_FACE_HUB_TOKEN` (`hfTokenSecretAttrs`). Delivery: shell init for bash, zsh, nushell; on Linux also `~/.config/environment.d/50-sops-secrets.conf` plus `systemctl --user set-environment`; on Darwin a launchd agent that calls `launchctl setenv`.
2. Keyring secret. `sops-keyring.nix` (Linux only) copies a curated subset into libsecret (gnome-keyring) for the nono sandbox broker. The map is `agentKeyMap`: `openrouter-api-key`, `context7-api-key`, and `agent-pat` (stored as `github_token`).
3. Plain `sops.secrets` file. Declare `sops.secrets."<yaml/path>"` and read `.path` in the consumer. Examples: `mini/media/**` in `hosts/mini/services/media/`, `mini/backup/**`, `mini/git/deploy-key`, `cachix/auth-token`.
4. `sops.templates`. Declare the secrets, then render a file with `config.sops.placeholder.<attr>`. Current templates:
   - `caddy.env` (`hosts/mini/services/caddy.nix`): `cloudflare_dns_api_token`, `tailscale_authkey`, `hermes_dashboard_basic_auth_hash`.
   - `hermes.env` (`hosts/mini/services/hermes.nix`): `openrouter_api_key`, `agent_pat`, `hf_token`, `kagi/session_token`, `context7_api_key`, `matrix/hermes_*`, `telegram/*`.
   - `matrix-continuwuity.env` (`hosts/mini/services/matrix.nix`): `matrix/registration_token`.
   - `mini-llm-hf.env` (`hosts/mini/services/llm/default.nix`): `hf_token`.
   - `networkmanager-yukikaze.env` (`modules/nixos/home-wifi.nix`): `wifi/yukikaze_psk`.
   - `kagi.toml` (`security.nix`, HM): `kagi-api-key`, `kagi-session-token` -> `~/.kagi.toml`.
   - `vicinae-github.json` (`modules/profiles/apps/vicinae.nix`, HM): `github-token`, only if that attribute exists.

## Procedure: add a secret

1. Choose the wiring form. Do not add a new form without a reason.
2. Set the value: `<cmd> | just secret-set <slash/path>`. The recipe refuses a terminal on stdin. For single-line values, pipe through `tr -d '\n'` first. Or edit with `sops secrets/secrets.yaml`.
3. Declare the secret in the consuming module.
4. Add a row to `secrets/SCHEMA.md` with path, source, consumer, and runtime host.
5. If recipients changed, run `sops updatekeys secrets/secrets.yaml`.

## Just recipes

- `secret-set <path>`: set one key from stdin, no editor.
- `setup-age-editor`: create the editor key.
- `setup-age-darwin`: same as `setup-age-editor`, for caya.
- `bootstrap-sops-host-key`: first install only, host path must be empty.
- `bootstrap-sops-host-key-from-editor`: temporary copy of the editor key as host key. Rotate before production.
- `rotate-sops-host-key`: back up, generate a new host key, print the pubkey. Update `.sops.yaml` and `updatekeys` before switch.
- `verify-sops-host-key <anchor>`: compare host pubkey with the anchor. Fails if host key equals editor key.
- `sync-1password`: push secrets to the 1Password vault on Darwin.
- `sync-media-secrets-to-pass`: push `mini/media/**` to Proton Pass.

## Known schema gaps

`secrets/SCHEMA.md` currently lacks rows for `cloudflare_dns_api_token`, `tailscale_authkey`, `hermes_dashboard_basic_auth_hash`, `hf_token`, `telegram/bot_token`, `telegram/allowed_users`, and `telegram/home_channel`. Its `hermes/env` row is stale: hermes reads the `hermes.env` template, not a `hermes/env` key. Correct these when you touch the schema.

## Safety rules

- Never print secret values in terminal output.
- Never commit plaintext `secrets.yaml` or `.flake-host` (`.flake-host` is gitignored).
- Do not weaken permissions to make a service start. Fix ownership, mode, or key placement.

## Checks

- Make sure that the schema row, the YAML key, and the Nix `key`/attribute agree.
- Make sure that a template consumer declares every placeholder it uses.
- For host runtime key changes, use `just verify-sops-host-key <hostKey>`.
