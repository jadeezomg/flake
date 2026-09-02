# Shared CLI Tools (NixOS + Darwin)

## File & Text Processing

| Tool | Command | Notes |
|------|---------|-------|
| bat | `bat <file>` | Cat with syntax highlighting, paging |
| ripgrep | `rg <pattern>` | Faster grep; `--smart-case`, `-l` for file names only |
| fd | `fd <name>` | Fast find; `--type f/d`, `-e ext` for extension |
| sd | `sd 'old' 'new' file` | Sed replacement; simpler syntax |
| fzf | `fzf` | Fuzzy finder; pipe anything in (still used for HM `programs.fzf` widgets) |
| television | `tv` | `just` / `flake` with no args run `tv … just-recipes` (cable TOML only; **F5** runs a recipe) |
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
| nixd | LSP | Nix language server (helix, Zed, VSCode) |
| treefmt | `treefmt -q .` | Nix formatter multiplexer (flake formatter via nixfmt-tree) |
| nixfmt | `nixfmt file.nix` | Official Nix formatter (used by treefmt and editors) |
| deadnix | `deadnix .` | Finds unused bindings (run by `flake fmt` and `flake lint`) |
| statix | `statix check .` | Nix antipattern linter (run by `flake lint`) |
| nix-update | `nix-update <pkg>` | Bumps a package's version and hash |
| nh | `nh os switch` | Nix helper (use `flake` recipes instead) |
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
| bash-language-server | LSP | Calls shellcheck and shfmt; wired into helix, Zed, VSCode |

### General
| Tool | Command | Notes |
|------|---------|-------|
| just | `just <recipe>` | Task runner (primary build tool) |
| just-lsp | LSP | Justfile language server; wired into helix, Zed, VSCode |
| mmdc | `mmdc -i in.mmd -o out.svg` | mermaid-cli renderer (for prose, use ```mermaid fences) |

### Markdown
| Tool | Command | Notes |
|------|---------|-------|
| marksman | LSP | Heading references, TOC action, link diagnostics |
| markdownlint-cli2 | `markdownlint-cli2 '**/*.md'` | Style linter; no config and no caller in this repo |

### Agents
| Tool | Command | Notes |
|------|---------|-------|
| apm | `apm install -g` | Agent Package Manager; owns global skills + MCP |
| kagi | `kagi search "<q>"` | Web search, page extract, referenced answers |
| ctx7 | `ctx7 library <name> "<q>"` | Library and SDK docs |

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
