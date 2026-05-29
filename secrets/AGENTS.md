# SECRETS

Encrypted with `sops` + `age`. Full guide: [docs/secrets/sops-age-keys.md](../docs/secrets/sops-age-keys.md).

## Key model

| Key | Path | `.sops.yaml` |
|-----|------|--------------|
| **Editor** (edit secrets) | `~/.config/sops/age/keys.txt` | `&editor` |
| **NixOS host runtime** | `/var/lib/private/sops/age/keys.txt` | `&framework`, `&desktop`, `&mini` |
| **Caya HM/runtime** | `~/.config/sops/age/keys.txt` on caya | `&caya` |

All recipients can decrypt the whole secrets file (see SCHEMA.md).

```bash
just setup-age-editor                  # editor key
just setup-age-darwin                    # caya HM/runtime key (same path)
just bootstrap-sops-host-key             # first install only (empty host path)
just rotate-sops-host-key                # dedicated host key after Phase 1 copy
just verify-sops-host-key framework      # post-rotation check
sops updatekeys secrets/secrets.yaml     # after .sops.yaml changes
```

## Gotchas

- Never commit `secrets.yaml` unencrypted or `.flake-host`
- `bootstrap-sops-host-key` does **not** replace an existing host key — use `rotate-sops-host-key`
- Do **not** put SSH login private keys or age host private keys in sops
