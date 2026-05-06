# NixOS-Specific CLI Tools

These tools are only available on NixOS (desktop/framework hosts).

## System Information & Hardware

| Tool | Command | Notes |
|------|---------|-------|
| inxi | `inxi -F` | Full hardware info report |
| pciutils | `lspci` | PCI devices (GPU, etc.) |
| usbutils | `lsusb` | USB devices |
| lm_sensors | `sensors` | Hardware temperatures/voltages |
| smartmontools | `smartctl -a /dev/sda` | Disk health |

## System Utilities

| Tool | Command | Notes |
|------|---------|-------|
| psmisc | `killall`, `pstree`, `fuser` | Process tools |
| util-linux | `lsblk`, `blkid`, `mount`, `umount` | Core Linux utilities |
| coreutils | `uutils-coreutils` | Standard tools (Rust rewrite) |
| autorandr | `autorandr --change` | Auto-configure display on connect |

## Development

| Tool | Notes |
|------|-------|
| gdb | GNU debugger (`gdb ./binary`) |

## Gaming (desktop host only)

| Tool | Notes |
|------|-------|
| steamcmd | Steam command-line interface |
| mangohud | In-game overlay (FPS, temps) |
| protonup-ng / protonup-rs | Update Proton/GE versions |
| heroic | Launcher for Epic/GOG games |

## LLM Tools (NixOS)

| Tool | Notes |
|------|-------|
| vllm | LLM serving engine |

## nix-index (fish integration)

`nix-index` is integrated with fish: when a command is not found, it suggests the nixpkgs package that provides it.

## Key Files

- `/etc/nixos/` - NixOS config (but prefer flake)
- `~/.dotfiles/flake/` - The flake root (`zf` to navigate there)
- `.flake-host` - Active host (desktop/framework)
