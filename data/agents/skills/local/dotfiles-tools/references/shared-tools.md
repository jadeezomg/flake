# Shared CLI Tools (NixOS + Darwin)

## File & Text Processing

| Tool | Command | Notes |
|------|---------|-------|
| bat | `bat <file>` | Cat with syntax highlighting, paging |
| ripgrep | `rg <pattern>` | Faster grep; `--smart-case`, `-l` for file names only |
| fd | `fd <name>` | Fast find; `--type f/d`, `-e ext` for extension |
| sd | `sd 'old' 'new' file` | Sed replacement; simpler syntax |
| fzf | `fzf` | Fuzzy finder; pipe anything in |
| jq | `jq '.key'` | JSON processor; `-r` for raw output |
| yq | `yq '.key'` | YAML/JSON/XML/TOML processor |

## Filesystem

| Tool | Command | Notes |
|------|---------|-------|
| trash | `trash <path>` | Preferred delete (user shell alias); never `rm`/`rmdir` |
| gio | `gio trash <path>` | Trash via GLib; **required under `sudo`** (alias unavailable) |
| dust | `dust` | Visual disk usage (like du but better) |
| difftastic | `difft` | Structural diff (understands syntax) |
| p7zip | `7z` | Archive tool |

## Git & Version Control

| Tool | Command | Notes |
|------|---------|-------|
| git | `git` | Standard (delta configured as pager) |
| gh | `gh pr`, `gh issue`, `gh repo` | GitHub CLI |
| act | `act` | Run GitHub Actions locally |

## Networking

| Tool | Command | Notes |
|------|---------|-------|
| xh | `xh GET url` | Better curl/httpie |
| curl | `curl` | Standard HTTP client |
| gping | `gping host` | Visual ping with graph |
| dig | `dig domain` | DNS lookup |

## Containers

| Tool | Command | Notes |
|------|---------|-------|
| podman | `podman ps` | OCI container runtime |
| podman-compose | `podman-compose up -d` | Compose-style workflows |

## Development: Nix Tools

| Tool | Command | Notes |
|------|---------|-------|
| nil | LSP | Nix language server |
| nixd | LSP | Alternative Nix language server |
| alejandra | `alejandra file.nix` | Opinionated Nix formatter |
| nh | `nh os switch` | Nix helper (use `just` instead) |
| devenv | `devenv shell` | Dev environments |

## Development: Language Tools

### Python
| Tool | Command | Notes |
|------|---------|-------|
| uv | `uv add pkg` | Fast package manager |
| ruff | `ruff check .` / `ruff format .` | Linter + formatter |
| ty | `ty check` | Type checker |
| python3 | `python3` | Python (with pip, lz4) |

### JavaScript / TypeScript
| Tool | Command | Notes |
|------|---------|-------|
| node | `node` | Node.js 24 |
| bun | `bun run`, `bun add` | Fast JS toolkit |
| yarn | `yarn` | yarn-berry |
| tsc | `tsc` | TypeScript compiler |
| biome | `biome check .` | Linter + formatter |

### Rust
| Tool | Command | Notes |
|------|---------|-------|
| rustup | `rustup toolchain install` | Rust toolchain manager |
| bacon | `bacon` | Background compiler watcher |
| cargo-info | `cargo info pkg` | Crate info |

### Shell
| Tool | Command | Notes |
|------|---------|-------|
| shfmt | `shfmt -w file.sh` | Shell formatter |
| shellcheck | `shellcheck file.sh` | Shell linter |

### General
| Tool | Command | Notes |
|------|---------|-------|
| just | `just <recipe>` | Task runner (primary build tool) |
| mermaid | inline in markdown fences | Use `\`\`\`mermaid` blocks |

## Security / Secrets

| Tool | Command | Notes |
|------|---------|-------|
| age | `age -r pubkey -o out.age` | File encryption |
| sops | `sops secrets.yaml` | Secrets management |


## PDF Tools

| Tool | Notes |
|------|-------|
| pdftotext, pdfinfo | From poppler-utils |
| qpdf | PDF manipulation/inspection |
| pdftk | PDF merging, splitting |

## Task Running

```bash
just <recipe>    # preferred - see Justfile for all recipes
just --list      # show all recipes
```
