# dotfiles

jadee's NixOS + nix-darwin flake. Manages three machines with shared home-manager config.

## Hosts

| Host | System | Hardware |
|---|---|---|
| `desktop` | x86_64-linux | NVIDIA GPU |
| `framework` | x86_64-linux | AMD, Framework 13 7040 |
| `caya` | aarch64-darwin | Apple Silicon |

Active host set in `.flake-host`. Change with `just init`.

## Quick start

```bash
just switch       # flake check + switch
just switch-fast  # skip flake check
just build-dry    # dry run
just rollback     # rollback
just fmt          # format all .nix files
just update       # preview input updates
```

## Structure

```
flake/
├── flake.nix              # flake-parts entrypoint, inputs, per-system outputs
├── Justfile               # all build/switch/gc/format recipes
├── lib/
│   └── pkgs.nix           # getPkgs / getPkgsStable helpers
├── parts/
│   └── hosts.nix          # builds nixosConfigurations + darwinConfigurations
├── data/
│   ├── hosts/hosts.nix    # host definitions (system, username, homeDirectory)
│   └── users/users.nix    # user definitions
├── hosts/
│   ├── desktop/           # desktop-specific NixOS config
│   ├── framework/         # framework-specific NixOS config
│   └── caya/              # caya-specific nix-darwin config + homebrew taps
├── modules/
│   ├── shared/            # cross-platform system modules
│   ├── nixos/             # Linux-only system modules
│   └── darwin/            # macOS-only system modules
├── home/
│   ├── shared/            # cross-platform home-manager config
│   │   ├── apps/          # browsers, editors, IDEs, terminals
│   │   ├── assets/        # fonts, icons, stylix theme, wallpapers
│   │   ├── development/
│   │   │   ├── languages/ # per-language configs
│   │   │   └── tooling/   # cloud, databases, llm, dev tools
│   │   ├── security/      # sops-nix home-manager secrets
│   │   ├── shells/        # bash, fish, nushell, zsh + secret env exports
│   │   └── utils/         # core, filesystem, monitoring, text tools
│   ├── nixos/             # Linux-only home-manager config
│   └── darwin/            # macOS-only home-manager config
├── packages/              # custom flake packages
│   ├── iosevka-aile/
│   ├── iosevka-etoile/
│   ├── context7/
│   ├── kagi-ken/
│   └── kagi-ken-cli/
├── scripts/               # Justfile helpers + uv/python scripts
└── secrets/secrets.yaml   # sops-nix age-encrypted secrets
```

## Key inputs

| Input | Purpose |
|---|---|
| `nixpkgs` | nixos-unstable |
| `nixpkgs-stable` | nixos-25.11 |
| `home-manager` | user environment |
| `sops-nix` | secret management |
| `stylix` | system-wide theming |
| `lanzaboote` | secure boot |
| `niri` | Wayland compositor |
| `quickshell` | shell/bar framework |
| `determinate` | Nix daemon |
| `nix-darwin` | macOS config |
| `nix-homebrew` | Homebrew via Nix |

## Secrets

Encrypted with age/sops. Edit with `sops secrets/secrets.yaml`.
Keys live at `~/.config/sops/age/keys.txt`.
Secrets auto-exported as env vars in all shells via `home/shared/shells/sops-shell-secrets.nix`.

## Adding things

| Goal | Location |
|---|---|
| System package, all Linux hosts | `modules/shared/` |
| System package, one host | `hosts/<name>/default.nix` |
| User package (home-manager) | `home/shared/apps/` |
| NixOS service/daemon | `modules/nixos/services/` |
| Language dev config | `home/shared/development/languages/<lang>.nix` |
| New secret | `sops secrets/secrets.yaml`, then declare in `modules/shared/security/encryption/age-sops.nix` |
