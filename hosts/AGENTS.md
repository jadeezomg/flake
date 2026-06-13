# HOSTS

## Purpose

Per-machine configuration: host facts, profile toggles, and host-specific system overrides.

## Use skills

- `flake-structure` — host folder ownership and top-level flake wiring.
- `module-structure` — profile toggles and profile/module interactions.
- `secrets-structure` — host runtime age keys and host-specific secrets.

## Local hazards

- Each host folder uses `host.nix` for facts, `profiles.nix` for `dotfiles.profiles.*`, and `default.nix` for host-specific system overrides.
- `.flake-host` selects the active host and must not be committed.
- `stateVersion` is per-host; never bump it without auditing release notes, and never lower it.
- `extraUsers` also receive Home Manager configs through `parts/hosts.nix`.
