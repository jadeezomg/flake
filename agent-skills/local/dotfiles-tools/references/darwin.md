# macOS (Darwin)-Specific CLI Tools

These tools are only available on the caya host (aarch64 Apple Silicon, macOS).

## Homebrew CLI Tools

| Tool | Command | Notes |
|------|---------|-------|
| rbenv | `rbenv install 3.x`, `rbenv global` | Ruby version manager |
| ruby-build | used by rbenv | Ruby compilation |

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