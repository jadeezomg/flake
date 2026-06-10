# Profiles (`dotfiles.profiles`)

All profile content lives in one tree: [`modules/profiles/`](../modules/profiles/). The tree is its own index — `dotfiles.profiles.<name>` is implemented by `modules/profiles/<name>.nix` (or `<name>/`):

- **Options, defaults, and server-class assertions** are declared centrally in [`modules/profiles/default.nix`](../modules/profiles/default.nix).
- **Per-host toggles** live in `hosts/<name>/profiles.nix`.
- **Platform differences** are handled inside each profile: package lists use `lib.optionals (!isDarwin) [...]` inline; option namespaces that only exist on one platform live in platform leaves imported conditionally (`desktop.nix`, `gaming.nix`, `integrations.nix`, `apps/media.nix` are Linux-only; `work/darwin.nix` holds the work profile's Homebrew side).
- **Home Manager halves** of profile-gated apps still live under [`home/`](../home/), gated on `osConfig.dotfiles.profiles.*`.

Meta-profiles (`apps`, `devenv`, `integrations`) `mkDefault`-enable their sub-toggles when turned on; override individual sub-flags per host after enabling the meta-flag.
