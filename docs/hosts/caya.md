# Caya — operations

Single reference for the `caya` host (MacBook, aarch64-darwin, work laptop).

**Scope:** only what is not readable from the flake. `hosts/caya/**` and the module tree answer every "what is configured" question. When the two disagree, the flake wins. Fix this file.

Nothing connects into caya (`sshAddress = null` in `hosts/caya/host.nix`). Do every step on caya itself, in a normal terminal. The login shell is nushell.

---

## 1. Darwin workflows

caya is an `aarch64-darwin` host with the user `jonashippauf` (`caya-jonas` in `data/users/users.nix`). `hosts/caya/profiles.nix` turns on the `work` profile. Its Darwin part, `modules/profiles/work/darwin/default.nix`, holds the Homebrew configuration.

### Add a Homebrew cask or tap

1. Add the cask to `homebrew.casks` in `modules/profiles/work/darwin/default.nix`. A cask from a third-party tap takes the full name, for example `nkzw-tech/tap/codiff`.
2. For a new tap, add its repo to `flake.nix` as an input with `flake = false`, as `homebrew-nkzw-tap` does. Then add the input to `nix-homebrew.taps` in `hosts/caya/default.nix`. `homebrew.taps` takes its names from that list.
3. Also add a third-party tap to `nix-homebrew.trust.taps`, for example `nkzw-tech/tap`. Homebrew 6.0 and later does not load casks from a tap that it does not trust.
4. To set the macOS defaults of the app, add a file to `modules/profiles/work/darwin/brew-casks/` and import it in `brew-casks/default.nix`.

The activation uses `cleanup = "uninstall"`. If you remove a cask from the list, the next switch uninstalls it.

### Homebrew version pin

nix-homebrew pins its own Homebrew release. `hosts/caya/default.nix` replaces it with Homebrew `brewVersion` (7.0.11) through `nix-homebrew.package`. Older releases cannot read `zap :not_required` in the `font-sf-mono` and `font-sf-pro` casks. The `newerBrew` guard (`lib/expiry.nix`) compares the pin of nix-homebrew with `brewVersion`. If nix-homebrew pins `brewVersion` or later, the evaluation prints a warning and the override stops. Then delete `newerBrew` and the `nix-homebrew.package` override.

### Environment variables for GUI apps

An app that starts from Finder, the Dock or Spotlight does not see shell exports. To give a GUI app a variable, add it to `launchd.user.envVariables`. The `xdg-env` launch agent in `modules/darwin/default.nix` runs `launchctl setenv` for each entry at every login. `CODIFF_CODEX_PATH` in `modules/profiles/work/darwin/default.nix` is an example.

### Nix daemon configuration

Determinate Nix owns `/etc/nix/nix.conf`, so `nix.settings` has no effect on caya. Put the daemon configuration in `determinateNix.customSettings` in `modules/darwin/nix.nix`. Determinate writes it to `/etc/nix/nix.custom.conf`. The binary caches come from the entries in `lib/nix-caches.nix` that have `darwin = true`. Do not set `nix.enable = true`.

### Quit apps before a switch

On caya, `just switch` runs `scripts/shell/quit-apps.bash` after the build and before the activation. The script asks each open app to quit, as Cmd+Q does. It never forces an app to quit. Terminals, Finder and menu bar apps stay open. `just switch-fast` does not run this step. To see the list of apps first, run `just quit-apps --dry-run`.

## 2. What caya does not get

- **No agent session push.** `modules/profiles/devenv/agents/session-push.nix` is Linux only, and work sessions stay off mini (D1). caya has no `agentPushKey`.