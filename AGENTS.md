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
├── flake.nix              # flake-parts entrypoint, inputs, perSystem outputs
├── Justfile               # all build/switch/gc/format recipes
├── scripts/               # shell/ (bash for Justfile) + pyproject + src/flake_scripts (uv)
├── lib/
│   └── pkgs.nix           # getPkgs / getPkgsStable (used by flake.nix + parts/)
├── parts/
│   ├── hosts.nix          # builds nixosConfigurations + darwinConfigurations
│   └── overlays/          # per-system nixpkgs overlays
├── data/
│   ├── hosts/hosts.nix    # host definitions (desktop, framework, caya)
│   └── users/users.nix    # user definitions (jadee, caya-jonas)
├── hosts/
│   ├── desktop/           # x86_64-linux desktop (NVIDIA)
│   ├── framework/         # x86_64-linux laptop (AMD, Framework 13 7040)
│   └── caya/              # aarch64-darwin (also holds nix-homebrew tap config)
├── modules/
│   ├── shared/            # cross-platform system modules
│   ├── nixos/             # Linux-only system modules
│   └── darwin/            # macOS-only system modules
├── home/
│   ├── shared/            # cross-platform home-manager config
│   │   ├── apps/          # browsers, editors, IDEs, terminals, tools
│   │   ├── assets/        # fonts, icons, theme (stylix), wallpapers, file symlinks
│   │   ├── development/
│   │   │   ├── languages/ # per-language configs (57 files)
│   │   │   └── tooling/   # cloud, databases, llm, tools
│   │   ├── shells/        # bash, fish, nushell, zsh
│   │   └── utils/         # core, filesystem, monitoring, text
│   ├── nixos/             # Linux-only home-manager config
│   └── darwin/            # macOS-only home-manager config
├── packages/              # custom flake packages (iosevka-aile, iosevka-etoile)
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

## Hydra API (nixpkgs Build Status)

Use the Hydra API to check whether a package is built and cached before adding it. No authentication required for read-only queries. Always pass `Accept: application/json`.

**Base URL**: `https://hydra.nixos.org`

**Check if a package built successfully** (most common use case):
```bash
# Latest successful build for a package on a specific system
curl -sL -H "Accept: application/json" \
  "https://hydra.nixos.org/job/nixpkgs/unstable/<attr>.<system>/latest-finished" | jq '{success, finished, nixname}'

# Examples
curl -sL -H "Accept: application/json" \
  "https://hydra.nixos.org/job/nixpkgs/unstable/ripgrep.x86_64-linux/latest-finished" | jq '{success, nixname}'

curl -sL -H "Accept: application/json" \
  "https://hydra.nixos.org/job/nixpkgs/unstable/ripgrep.aarch64-darwin/latest-finished" | jq '{success, nixname}'
```

**Check multiple systems at once:**
```bash
for system in x86_64-linux aarch64-darwin; do
  echo "$system: $(curl -sL -H "Accept: application/json" \
    "https://hydra.nixos.org/job/nixpkgs/unstable/<attr>.$system/latest-finished" | jq -r '.success')"
done
```

**Get the store path of a built package** (to verify it's in cache.nixos.org):
```bash
curl -sL -H "Accept: application/json" \
  "https://hydra.nixos.org/job/nixpkgs/unstable/<attr>.x86_64-linux/latest-finished" \
  | jq -r '.buildoutputs.out.path'
```

**Key response fields:**
- `success` — `true` if the build passed
- `finished` — `1` if complete (not queued)
- `buildstatus` — `0` = success, non-zero = failure
- `nixname` — the derivation name (e.g. `ripgrep-14.1.1`)
- `buildoutputs.out.path` — the `/nix/store/...` path

**Jobsets**: `nixpkgs/unstable` (nixos-unstable channel), `nixpkgs/trunk` (master)

**Systems**: `x86_64-linux`, `aarch64-linux`, `x86_64-darwin`, `aarch64-darwin`

**Alternative — `hydra-check` CLI** (available in nixpkgs):
```bash
nix run nixpkgs#hydra-check -- ripgrep --arch x86_64-linux --channel unstable
nix run nixpkgs#hydra-check -- ripgrep --json
```

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
| Language dev config | `home/shared/development/languages/<lang>.nix` |
| Dev tooling (cloud, db, llm) | `home/shared/development/tooling/` |
| Theme, fonts, file symlinks | `home/shared/assets/` |

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
| `inputs` | flake inputs (access individual inputs via `inputs.sops-nix` etc.) |
| `hostData` | all host definitions from `data/hosts/hosts.nix` |
| `hostKey` | current host name (`"desktop"`, `"framework"`, `"caya"`) |
| `host` | current host attrset from hostData |
| `user` | current username |
| `isDarwin` | true on macOS |
| `system` | system string, NixOS only (`"x86_64-linux"`) |
| `pkgs-stable` | nixpkgs-stable package set |

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
