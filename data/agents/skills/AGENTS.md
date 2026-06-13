# AGENT SKILLS

## Purpose

Global-install agent skills managed by this flake and installed into user agent skill directories by Home Manager.

## Use skills

- `agent-structure` — global-install skills vs project-only root `skills/`, installed copies, and agent config wiring.

## Local hazards

- Skills here install globally into `~/.claude/skills/` and `~/.agents/skills/`; project-only skills belong in root `skills/`.
- `local/` is still global-install; use it only for dotfiles-specific skills that should follow the user into every repo.
- Do not edit installed copies under `~/.claude/skills/` or `~/.agents/skills/`.
- Category folders mirror the pinned `skills-mattpocock` input; keep upstream-sync exceptions in `.upstream-ignore`.
