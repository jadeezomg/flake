# Caya — operations

Single reference for the `caya` host (MacBook, aarch64-darwin, work laptop).

**Scope:** only what is not readable from the flake. `hosts/caya/**` and the module tree answer every "what is configured" question. When the two disagree, the flake wins. Fix this file.

Nothing connects into caya (`sshAddress = null` in `hosts/caya/host.nix`). Do every step on caya itself, in a normal terminal. The login shell is nushell.

---

## 1. Move the flake checkout to `~/git/flake` (2026-10)

All git repos live at `~/git/<repo>`, the flake included (D9 in [session-management-plan.md](../agents/session-management-plan.md)). `dotfiles.flakeRoot` now defaults to `~/git/flake`. The first switch from the new path also sets the black theme variant on caya.

1. Pull and move the checkout. `bash -c` keeps `&&` working in nushell:

   ```
   bash -c 'git -C ~/.dotfiles/flake pull --ff-only && git -C ~/.dotfiles/flake remote set-url origin git@github.com:jadeezomg/flake.git && mkdir -p ~/git && mv ~/.dotfiles/flake ~/git/flake && ln -s ../git/flake ~/.dotfiles/flake'
   ```

2. Make sure that the move is complete:

   ```
   ls -la ~/.dotfiles
   open ~/git/flake/.flake-host
   ```

   The first command shows `flake -> ../git/flake`. The second shows `caya`.

3. Switch from the new path. The switch asks for the sudo password:

   ```
   cd ~/git/flake; just switch-fast
   ```

   This switch repoints the live symlinks to `~/git/flake`, installs the `tuios` brew, and sets the black theme. If it fails, keep the error output.

4. Open a new terminal. Make sure that the new path is in use:

   ```
   $env.FLAKE
   tuios --version
   ^readlink ~/.claude/settings.json
   ```

   Expected: `/Users/<you>/git/flake`, `tuios version 0.11.0`, and a target under `.../git/flake/...`.

5. If `~/.claude/CLAUDE.md` exists, move it to the trash. It is an old link that no module manages, and Claude Code then loads the global instructions twice:

   ```
   ls -la ~/.claude/CLAUDE.md
   trash ~/.claude/CLAUDE.md
   ```

   On caya, `trash` is the brew from the work profile. The `gio trash` alias exists on Linux only.

6. When nothing uses the old path, remove the symlink: `trash ~/.dotfiles/flake`.

## 2. What caya does not get

- **No agent session push.** `modules/profiles/devenv/agents/session-push.nix` is Linux only, and work sessions stay off mini (D1). caya has no `agentPushKey`.