# macOS (Darwin)-Specific CLI Tools

These tools are only available on the caya host (aarch64 Apple Silicon, macOS).

## Homebrew CLI Tools

| Tool | Command | Notes |
|------|---------|-------|
| rbenv | `rbenv install 3.x`, `rbenv global` | Ruby version manager |
| ruby-build | used by rbenv | Ruby compilation |

## Homebrew Casks (GUI Apps with CLI components)

| App | CLI / Notes |
|-----|------------|
| 1Password | `op` CLI (`op run`, `op inject`, `op item get`) |
| Docker Desktop | `docker`, `docker compose` |
| Raycast | Spotlight replacement (hotkey) |
| LM Studio | Local LLM GUI |

## 1Password CLI (op)

```bash
op signin                          # authenticate
op item get "Item Name"            # get credentials
op run -- my-command               # inject secrets into command env
op inject -i template.tpl          # inject into template
op item list --vault Private       # list items
```

## macOS System Tools (always available)

| Tool | Notes |
|------|-------|
| `open` | Open files/URLs/apps (`open -a AppName`) |
| `pbcopy` / `pbpaste` | Clipboard I/O |
| `defaults` | Read/write macOS preferences |
| `launchctl` | Manage launch agents/daemons |
| `plutil` | Property list (plist) tool |
| `security` | Keychain access |
| `sips` | Image processing (resize, convert) |
| `say` | Text-to-speech |
| `mdls` | Spotlight metadata |
| `mdfind` | Spotlight search |
| `scutil` | System configuration |
| `dscl` | Directory services |
| `xcode-select` | Xcode CLI tools |

## nix-darwin Integration

macOS is managed via nix-darwin (caya host). The flake handles:
- Homebrew casks and formulas declaratively
- System defaults (`system.defaults.*`)
- Launch agents
- Shell configuration

```bash
# Always use just recipes to switch (never nix-darwin directly)
just switch        # full switch
just switch-fast   # skip flake check
```

## Docker on macOS

Docker Desktop is installed via Homebrew cask. The socket is at `~/.docker/run/docker.sock` or `/var/run/docker.sock` via compatibility symlink.

```bash
docker ps
docker compose up -d
```

## Key Differences from NixOS

| Feature | macOS (caya) | NixOS |
|---------|--------------|-------|
| Package manager | Nix + Homebrew | Nix only |
| System manager | nix-darwin | NixOS modules |
| Docker | Docker Desktop (Homebrew) | Docker daemon (system service) |
| GPU monitoring | nvtop (Apple) | NVTOP for NVIDIA |
| Terminal | ghostty-bin (macOS build) | ghostty (Linux build) |
| Ruby | rbenv (Homebrew) | Direct nixpkgs |
| Languages | + Swift/sourcekit-lsp | + vllm, lmstudio |
