# Profiles (`dotfiles.profiles`)

All profile content lives in one tree: [`modules/profiles/`](../modules/profiles/). The tree is its own index — `dotfiles.profiles.<name>` is implemented by `modules/profiles/<name>.nix` (or `<name>/`):

- **Options, defaults, and server-class assertions** are declared centrally in [`modules/profiles/default.nix`](../modules/profiles/default.nix).
- **Per-host toggles** live in `hosts/<name>/profiles.nix`.
- **Platform differences** are handled inside each profile: package lists use `lib.optionals (!isDarwin) [...]` inline; option namespaces that only exist on one platform live in platform leaves imported conditionally (`desktop.nix`, `gaming.nix`, `integrations.nix`, `apps/media.nix` are Linux-only; `work/darwin.nix` holds the work profile's Homebrew side).
- **Home Manager halves** live inside each feature folder as `home.nix`/HM modules, pushed via `home-manager.sharedModules` when the profile is enabled (no `osConfig` gates; `home/` no longer exists). The unconditional base — sops + stylix HM modules and the `dotfiles.flakeRoot` option (`lib/home/dotfiles.nix`) — is wired in `parts/hosts.nix`.

Meta-profiles (`apps`, `devenv`, `integrations`) `mkDefault`-enable their sub-toggles when turned on; override individual sub-flags per host after enabling the meta-flag.
