# PROJECT KNOWLEDGE BASE

## Purpose

Single-flake, multi-host NixOS/Darwin dotfiles for `desktop`, `framework`, `caya`, and `mini`. Active host comes from `.flake-host` and must not be committed.

## Use skills

- `flake-structure` — top-level layout: hosts, parts, packages, lib, scripts, docs.
- `module-structure` — `modules/profiles/**` profile/app layout.
- `agent-structure` — root `skills/`, global `data/agents/`, and installed agent config.
- `secrets-structure` — SOPS/age secret layout and wiring.
- `theme-structure` — shared palette and generated app themes.
- `xdg-default-apps` — MIME defaults and desktop app ownership.

## Local hazards

- Use `flake` recipes; do not run bare `nixos-rebuild`, `home-manager switch`, or `nh` directly.
- Verify packages with live nixpkgs tooling before adding them; check cache availability for costly packages.
- Run `flake fmt` after editing `.nix` files.
- Run `git add` before Nix eval/build; flakes only see tracked files.
- Never commit secrets or `.flake-host`; use SOPS for encrypted secrets.
- Do not edit installed agent files under `~/.claude/`, `~/.agents/`, or `~/AGENTS.md`; edit this flake's sources.
