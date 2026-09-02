# Profiles (`dotfiles.profiles`)

All profile content lives in one tree: [`modules/profiles/`](../modules/profiles/). The tree is its own index — `dotfiles.profiles.<name>` is implemented by `modules/profiles/<name>.nix` (or `<name>/`):

- **Options, defaults, and server-class assertions** are declared centrally in [`modules/profiles/default.nix`](../modules/profiles/default.nix).
- **Per-host toggles** live in `hosts/<name>/profiles.nix`.
- **Platform differences** are handled inside each profile: package lists use `lib.optionals (!isDarwin) [...]` inline; option namespaces that only exist on one platform live in platform leaves imported conditionally (`desktop/`, `gaming.nix`, `integrations.nix`, `apps/media.nix` are Linux-only; `work/darwin/` holds the work profile's Homebrew side; platform-specific HM halves live in `linux/` / `darwin/` subfolders of their feature (e.g. `minimal/linux/`)).
- **Home Manager halves** live inside each feature folder as `home.nix`/HM modules, pushed via `home-manager.sharedModules` when the profile is enabled (no `osConfig` profile *gates* — modules may still read system *values* via `osConfig`, e.g. the login-manager choice; `home/` no longer exists). The unconditional base — sops + stylix HM modules and the `dotfiles.flakeRoot` option (`lib/home/dotfiles.nix`) — is wired in `parts/hosts.nix`.

**Hardware traits** ((`dotfiles.hardware.*`: wireless (wifi+BT combo), `gpu` enum incl. intel, `cpu.zen4`/`cpu.x3d`)) describe what a machine *is* — declared next to the profile options, implemented in `modules/profiles/hardware/`, set per host in `hosts/<name>/profiles.nix`.

Each profile is one `enable` flag. The category files under `apps/`, `devenv/`, and `devgui/` read the parent flag; only `devenv.languages.<name>.enable` (per language) and `apps.notes.enable` have their own toggles. `fonts.full`, `theme.gui`, `desktop.shell`, and `desktop.loginManager` are the remaining per-host knobs.
