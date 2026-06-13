# MODULES

## Purpose

System and Home Manager modules for shared platform configuration and `dotfiles.profiles.*` feature profiles.

## Use skills

- `module-structure` — profile/app layout, imports, Home Manager colocation, live symlink convention.
- `theme-structure` — palette and generated theme placement.
- `xdg-default-apps` — MIME defaults and desktop app ownership.

## Local hazards

- Do not use `../../` imports from modules; pure shared data comes through `dotfilesLib`, HM helpers through `config.lib.dotfiles`.
- Conditional files must be imported from a `default.nix`; unimported files are ignored.
- Keep profile toggles declared in `modules/profiles/default.nix` and enabled per host in `hosts/<name>/profiles.nix`.
- Darwin does not use the nixpkgs Nix daemon; do not re-enable `nix.enable` in Darwin modules.
- Live XDG symlinks are only for mutable app config, never secrets/databases/logs/caches/generated state.
