# Flake Build Scripts

Nushell-based build and management scripts for the NixOS flake configuration.

## Scripts

### Core Operations

- **`build.nu`** - Build configuration without switching
  - `build.nu <host> build` - Test build
  - `build.nu <host> boot` - Build for next boot
  - `build.nu <host> dry` - Dry run
  - `build.nu <host> dev` - Development build with trace

- **`switch.nu`** - Build and switch configuration
  - `switch.nu <host>` - Full rebuild with checks
  - `switch.nu <host> --fast` - Skip pre/post checks
  - `switch.nu <host> --check` - Run flake check (all systems) and exit before rebuild

- **`update.nu`** - Update flake inputs
  - `update.nu` - Update all inputs
  - `update.nu <input>` - Update specific input

### Maintenance

- **`gc.nu`** - Garbage collection
  - `gc.nu keep [N]` - Keep N generations (default: 5)
  - `gc.nu days [N]` - Remove older than N days (default: 7)
  - `gc.nu all` - Aggressive cleanup

- **`health.nu`** - System health check
  - Shows flake status, disk usage, generations, services

- **`generation.nu`** - Manage generations
  - `generation.nu list` - List all generations
  - `generation.nu switch <num>` - Switch to generation
  - `generation.nu delete <num>` - Delete generation

- **`rollback.nu`** - Rollback to previous generation

### Cache Management

- **`update-caches.nu`** - Update various caches
  - `--all` - Update all caches
  - `--all-except-nix` - Update all except nix-index
  - `--bat` - Update bat syntax cache
  - `--tldr` - Update tldr pages
  - `--nix` - Update nix-index
  - Placeholders: `--apps`, `--launcher`, `--wallpapers`, `--icons`

### Cleanup

- **`check-backups.nu`** - Scan for backup files
- **`clean-backups.nu`** - Remove backup files
  - `--dry` - Preview what would be removed

## Initialization

First, initialize the flake to set your default host:

```nu
./build/init.nu framework
# Or let it auto-detect:
./build/init.nu
```

This creates a `.flake-host` file in your flake directory with your default host.

## Usage

After initialization, scripts can be run without specifying the host:

```nu
./build/switch.nu          # Uses default host
./build/build.nu build      # Uses default host
./build/health.nu
./build/update.nu
```

You can still override the host if needed:

```nu
./build/switch.nu desktop   # Override to use desktop host
./build/build.nu desktop boot
```

Or add them to your PATH and use as commands.

## Configuration

Scripts use the `$FLAKE` environment variable (defaults to `~/.dotfiles/flake`).

Set in your nushell config:
```nu
$env.FLAKE = "~/.dotfiles/flake"
```

The default host is stored in `.flake-host` in your flake directory. You can change it anytime:
```nu
./build/init.nu <new-host>
```

Or manually edit `.flake-host` file.

