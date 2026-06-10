# Profile index (`dotfiles.profiles`)

**Purpose:** map each **`dotfiles.profiles.*`** toggle to the **Nix file(s)** that implement it. The exact package list always lives in those modules (and can drift with nixpkgs); this doc stays a **path index**, not a duplicate manifest.

**Declared options (defaults, descriptions, server assertions):**  
[`modules/shared/profiles/default.nix`](../modules/shared/profiles/default.nix)

**Per-host toggles:**  
[`hosts/<hostname>/profiles.nix`](../hosts/) (e.g. [`hosts/mini/profiles.nix`](../hosts/mini/profiles.nix))

**User-space packages / HM** often mirror the same flags under `osConfig.dotfiles.profiles` — not enumerated here; search under [`home/`](../home/).

---

## Cross-platform system profiles

| Toggle | Implementing module | Scope (what to open when editing) |
|--------|---------------------|-------------------------------------|
| **`minimal`** | [`modules/shared/profiles/minimal.nix`](../modules/shared/profiles/minimal.nix) | Core CLI set from [`lib/packages/minimal.nix`](../lib/packages/minimal.nix) (rg, fd, fzf, **television** (`tv`), yazi, …). |
| **`essentials`** | [`modules/shared/profiles/essentials.nix`](../modules/shared/profiles/essentials.nix) | Text/network helpers + Nix tooling (cachix, comma, nurl, …). |
| **`apps`** (meta) | [`modules/shared/profiles/apps/default.nix`](../modules/shared/profiles/apps/default.nix) | When on, `mkDefault`-enables all **`apps.*`** sub-flags below. |
| **`apps.browsers`** | Home Manager / other (browser stacks are not in this shared `apps/` tree) | Option text in `default.nix`; Zen etc. live under `home/`. |
| **`apps.terminals`** | [`modules/nixos/profiles/apps/terminals.nix`](../modules/nixos/profiles/apps/terminals.nix) | NixOS: alacritty, ghostty, kitty. |
| **`apps.editors`** | [`modules/nixos/profiles/apps/editors.nix`](../modules/nixos/profiles/apps/editors.nix) | NixOS: cursor, zed-editor; HM configs under `home/shared/apps/ides/`. |
| **`apps.files`** | [`modules/nixos/profiles/apps/files.nix`](../modules/nixos/profiles/apps/files.nix) | File managers / viewers on NixOS. |
| **`apps.comms`** | [`modules/nixos/profiles/apps/comms.nix`](../modules/nixos/profiles/apps/comms.nix) | Comms desktop apps. |
| **`apps.media`** | [`modules/nixos/profiles/apps/media.nix`](../modules/nixos/profiles/apps/media.nix) | Media players (e.g. pear-desktop path). |
| **`apps.notes`** | [`modules/shared/profiles/apps/notes.nix`](../modules/shared/profiles/apps/notes.nix) + [`modules/nixos/profiles/apps/notes.nix`](../modules/nixos/profiles/apps/notes.nix) | Cross-host notes packages + NixOS extras. |
| **`devenv`** (meta) | [`modules/shared/profiles/devenv/default.nix`](../modules/shared/profiles/devenv/default.nix) | When on, `mkDefault`-enables **`devenv.tools`**, **`cloud`**, **`containers`**, **`databases`**, **`llm.*`**, and **all language keys** listed below. |
| **`devenv.tools`** | [`modules/shared/profiles/devenv/tools.nix`](../modules/shared/profiles/devenv/tools.nix) | make/gcc/git-adjacent stack, **just**, gh, jj, formatters, uv, dive, … |
| **`devenv.cloud`** | [`modules/shared/profiles/devenv/cloud.nix`](../modules/shared/profiles/devenv/cloud.nix) | **awscli2**, **awslogs**. |
| **`devenv.containers`** | [`modules/shared/profiles/devenv/containers.nix`](../modules/shared/profiles/devenv/containers.nix) | podman (+ desktop UI), compose, Dockerfile LSP; Darwin docker shim. |
| **`devenv.databases`** | [`modules/shared/profiles/devenv/databases.nix`](../modules/shared/profiles/devenv/databases.nix) | Client tooling (e.g. **rainfrog**); server daemons are not here. |
| **`devenv.llm.agents`** | [`modules/shared/profiles/devenv/llm/agents.nix`](../modules/shared/profiles/devenv/llm/agents.nix) | Agent CLIs + flake-local tools (nono, codex, context7, kagi-cli, …). |
| **`devenv.llm.hosting`** | [`modules/shared/profiles/devenv/llm/hosting.nix`](../modules/shared/profiles/devenv/llm/hosting.nix) | Linux: **llama-cpp** (Vulkan override); Darwin: **podman** (unsloth path). |
| **`work`** | [`modules/shared/profiles/work.nix`](../modules/shared/profiles/work.nix) + [`modules/darwin/default.nix`](../modules/darwin/default.nix) (`homebrew`) | NixOS: postman, gws, workato CLI. Darwin: Homebrew casks/brews when `work.enable`. |
| **`server`** | [`modules/shared/profiles/server.nix`](../modules/shared/profiles/server.nix) + gates elsewhere | Steering flag (`server.enable`); gating in `boot.nix`, `networking.nix`, etc. — not a big package list. |
| **`gaming`** | [`modules/nixos/profiles/gaming.nix`](../modules/nixos/profiles/gaming.nix) | **Linux only:** Steam, GameMode, extra packages in that file. |

### `devenv.languages.*`

Each key has **`modules/shared/profiles/devenv/languages/<name>.nix`**:

| Key | Module |
|-----|--------|
| `data` | [`data.nix`](../modules/shared/profiles/devenv/languages/data.nix) |
| `docs` | [`docs.nix`](../modules/shared/profiles/devenv/languages/docs.nix) |
| `general` | [`general.nix`](../modules/shared/profiles/devenv/languages/general.nix) |
| `nix` | [`nix.nix`](../modules/shared/profiles/devenv/languages/nix.nix) |
| `python` | [`python.nix`](../modules/shared/profiles/devenv/languages/python.nix) |
| `ruby` | [`ruby.nix`](../modules/shared/profiles/devenv/languages/ruby.nix) |
| `rust` | [`rust.nix`](../modules/shared/profiles/devenv/languages/rust.nix) |
| `shell` | [`shell.nix`](../modules/shared/profiles/devenv/languages/shell.nix) |
| `swift` | [`swift.nix`](../modules/shared/profiles/devenv/languages/swift.nix) |
| `web` | [`web.nix`](../modules/shared/profiles/devenv/languages/web.nix) |

---

## Linux-only (`x86_64-linux` / NixOS)

These options exist for all hosts in `default.nix`, but implementing modules load only on **NixOS** (see imports under [`modules/nixos/`](../modules/nixos/)).

| Toggle | Implementing module | Scope |
|--------|---------------------|--------|
| **`desktop`** | [`modules/nixos/profiles/desktop.nix`](../modules/nixos/profiles/desktop.nix) | niri, DMS/greeter or GDM, greetd, polkit, sound stack, etc. |
| **`desktop.loginManager`** | same | `dms-greeter` vs `gdm`. |
| **`integrations`** (meta) | [`modules/nixos/profiles/integrations.nix`](../modules/nixos/profiles/integrations.nix) | When on, defaults **appimage** + **flatpak** on. |
| **`integrations.appimage`** | same | `programs.appimage` + binfmt. |
| **`integrations.flatpak`** | same | `services.flatpak` + Flathub activation script. |

---

## Related docs

- [`AGENTS.md`](../AGENTS.md) — workflows, “where to put things”, desktop stack.
- [`modules/AGENTS.md`](../modules/AGENTS.md) — `specialArgs`, profile table snippet.
- [`docs/hosts/mini.md`](hosts/mini.md) §10 — example server vs desktop profile mix.
