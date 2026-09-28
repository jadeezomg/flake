# PROJECT KNOWLEDGE BASE

## Purpose

Single-flake, multi-host NixOS/Darwin dotfiles for `desktop`, `framework`, `caya`, and `mini`. Active host comes from `.flake-host` and must not be committed.

## Use skills

- `flake-structure` — top-level layout: hosts, parts, packages, lib, scripts, docs.
- `module-structure` — `modules/profiles/**` profile/app layout.
- `overlays` — `parts/overlays/` and the self-expiring workaround pattern.
- `agent-structure` — `.agents/skills/`, global `data/agents/`, and installed agent config.
- `secrets-structure` — SOPS/age secret layout and wiring.
- `theme-structure` — shared palette and generated app themes.
- `xdg-default-apps` — MIME defaults and desktop app ownership.
- `llm-hosting` — mini's local LLM serving: backends, models, context/KV, embeddings, `just mini llm` ops.

## Local hazards

- Use `flake` recipes; do not run bare `nixos-rebuild`, `home-manager switch`, or `nh` directly.
- Never run build/switch commands yourself (`just build*`, `just switch`, or anything that evaluates/builds the system). Ask the user to run them and report back the output.
- Always edit flake/config on the host you are running on. Never edit configs over SSH on remotes (`mini`, etc.) — remotes are for inspect/deploy/ops only; the user reviews and approves local diffs first.
- Verify packages with live nixpkgs tooling before adding them; check cache availability for costly packages.
- Every workaround overlay must carry an expiry guard (`overlays` skill); nixpkgs bumps silently make them redundant.
- Run `flake fmt` after editing `.nix` files.
- Run `git add` before Nix eval/build; flakes only see tracked files.
- Never change `.flake-host` (read is fine; do not create, edit, or delete it). Never commit secrets or `.flake-host`; use SOPS for encrypted secrets.
- Do not edit installed agent files under `~/.claude/` or `~/AGENTS.md`. Skills and MCP there are APM's output and are overwritten on switch; edit `modules/profiles/devenv/agents/apm.nix` and `data/agents/skills/local/` instead.
- Non-nixpkgs packages that write mutable state need a removal path when dropped from the flake (see `packages/AGENTS.md`).
