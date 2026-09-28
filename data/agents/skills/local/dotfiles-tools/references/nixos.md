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
| protonup-ng | Update Proton/GE versions — binary is `protonup`, not `protonup-ng` |
| protonup-rs | Update Proton/GE versions (`protonup-rs`) |
| heroic | Launcher for Epic/GOG games |

## LLM Tools (NixOS)

| Tool | Notes |
|------|-------|
| llama-cpp | Local LLM inference (mini serves via systemd router) |

## nix-index

`nix-index` owns the command-not-found hook (`programs.command-not-found` is off). The hook covers bash and zsh only, so nushell — the default shell here — gets no suggestion. Query it directly with `nix-locate <bin>`.

## Key Files

- `/etc/nixos/` - NixOS config (but prefer flake)
- `~/.dotfiles/flake/` - The flake root, also `$FLAKE`
- `.flake-host` - Active host; never commit it and never edit it
