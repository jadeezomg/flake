# Nix Flake — AI Assistant Rules

This is jadee's NixOS flake. Three rules apply to every task:

1. **Always use `just` recipes** for building/switching — not bare `nh`, `nixos-rebuild`, or `home-manager switch`.
2. **Always verify packages and options** against nixpkgs before adding them.
3. **Always format** with `just fmt` after editing `.nix` files.

---

## Structure

**Root**: `/home/jadee/.dotfiles/flake`

```
flake/
├── flake.nix              # flake-parts orchestration, inputs
├── Justfile               # all build/switch/gc/format recipes
├── data/
│   ├── hosts/hosts.nix    # host definitions (desktop, framework, caya)
│   └── users/users.nix    # user definitions (jadee, caya-jonas)
├── hosts/
│   ├── desktop/           # x86_64-linux desktop (NVIDIA)
│   ├── framework/         # x86_64-linux laptop (AMD, Framework 13 7040)
│   └── caya/              # aarch64-darwin
├── modules/
│   ├── shared/            # cross-platform system modules
│   ├── nixos/             # Linux-only system modules
│   └── darwin/            # macOS-only system modules
├── home/
│   ├── shared/            # cross-platform home-manager config
│   ├── nixos/             # Linux-only home-manager config
│   └── darwin/            # macOS-only home-manager config
└── secrets/secrets.yaml   # sops-nix age-encrypted secrets
```

Each category folder has a `default.nix` that auto-imports its siblings.

---

## Building and Switching

Always run from the flake root. The Justfile sets `NH_FLAKE` automatically.

| Goal | Command |
|---|---|
| Full switch (flake check + nh switch) | `just switch` |
| Quick switch (skip flake check) | `just switch-fast` |
| Dry run | `just build-dry` |
| Validate flake only | `just switch-check` |
| Rollback | `just rollback` |
| Preview input updates | `just update` |
| Format all .nix files | `just fmt` |

**Never use** `nixos-rebuild switch`, `home-manager switch`, or bare `nh os switch /path`.

---

## Verifying Packages and Options

```bash
nix search nixpkgs <name>
```

- NixOS options: https://search.nixos.org/options
- home-manager options: https://nix-community.github.io/home-manager/options.xhtml

Use the exact attribute name from `nix search` (e.g. `pkgs.ripgrep`, not `pkgs.rg`).

---

## Where to Put Things

| Goal | Location |
|---|---|
| System package, all Linux hosts | `modules/shared/` appropriate category |
| System package, one host only | `hosts/<name>/default.nix` |
| User package (home-manager) | `home/shared/apps/` or appropriate category |
| Linux-only home config | `home/nixos/` appropriate category |
| NixOS service/daemon | `modules/nixos/services/` |
| Development tool | `modules/shared/development/` or `home/shared/development/` |
| Desktop/Wayland config | `modules/nixos/desktop/` or `home/nixos/desktop/` |
| Language dev config | `home/shared/development/<lang>.nix` |

Prefer editing existing files. If creating a new `.nix` file, add an import for it in that directory's `default.nix`.

---

## Module Coding Style

```nix
{ pkgs, ... }: {
  home.packages = with pkgs; [ ripgrep ];
}
```

Available `specialArgs` parameters:

| Parameter | What it is |
|---|---|
| `pkgs` | nixpkgs package set |
| `lib` | nixpkgs lib |
| `config` | current module config |
| `inputs` | flake inputs |
| `hostData` | all host definitions |
| `hostKey` | current host name (`"desktop"`, `"framework"`, `"caya"`) |
| `user` | current username |
| `isDarwin` | true on macOS |

```nix
# Conditional on host
lib.mkIf (hostKey == "desktop") { ... }

# Conditional list
lib.optionals (!isDarwin) [ pkgs.something ]

# Stylix color
config.lib.stylix.colors.base0D

# Flake input module
imports = [ inputs.some-flake.homeModules.default ];
```

---

## Secrets

```bash
sops secrets/secrets.yaml   # edit (decrypts, re-encrypts on save)
```

```nix
sops.secrets.my_secret = {};
# runtime path: config.sops.secrets.my_secret.path
```

---

## Hosts

| Host | System | Hardware |
|---|---|---|
| `desktop` | x86_64-linux | NVIDIA GPU |
| `framework` | x86_64-linux | AMD, Framework 13 7040 |
| `caya` | aarch64-darwin | Apple Silicon |

Active host is set in `.flake-host`. Run `just init` to change it.

---

## Workflow

1. Identify scope (system vs user, shared vs host-specific)
2. Verify package/option: `nix search nixpkgs <name>`
3. Find and edit the right existing `.nix` file
4. `just fmt`
5. `just switch`
