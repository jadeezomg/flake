# Flake streamline plan

## Context

Goal: **reduce complexity**. This plan replaces the earlier example-repo-driven draft after reviewing it against the actual flake.

Calibration facts from that review:

- The flake is ~12k lines of hand-written Nix (`home/` looks like 40k, but 33.5k is the generated `home/shared/assets/icons/nerdfonts.nix` data table — which has **zero consumers** and is deleted in Phase 4).
- Fonts are installed twice on every host, including the server: ~70 packages at system level (`modules/shared/fonts.nix`) plus a 64-font Home Manager catalogue (`home/shared/assets/fonts/`), with heavy overlap between the two lists.
- There are four hosts, not three: `desktop`, `framework`, `caya`, and `mini` (`hostClass = "server"`).
- `nix flake check` already evaluates every `nixosConfiguration` toplevel — Linux hosts have eval-level smoke coverage today. `darwinConfigurations` are the gap.
- The main complexity is not missing structure; it is **fragmentation**: profile content split across two parallel trees (`modules/shared/profiles/`, `modules/nixos/profiles/`, 37 files) plus HM halves under `home/`, with empty placeholder files as breadcrumbs and `docs/profiles.md` acting as the index a navigable structure would not need. One small feature (`apps.notes`) spans four files in three trees.

Every phase below is net-deletion or net-consolidation. No new frameworks; only mechanics the flake already has (`isDarwin`/`host` in specialArgs, `osConfig`, `home-manager.sharedModules`).

## Principles

- Keep `hosts/hosts.nix` as the source of host metadata; keep `parts/hosts.nix` generating host outputs.
- Keep `dotfiles.profiles.*` as the host-facing feature API; option declarations stay centralized in one `default.nix`.
- **Split by platform only at the leaf where an option namespace forces it; everything else splits by feature.**
- `home/` is the third parallel tree (shared/nixos/darwin split, ~105 files) and dissolves into profile feature folders over time (Phase 7) — small profile-gated apps first, rich config worlds (Zed, Zen, niri/DMS) last, never big-bang.
- Prefer eval-only checks over VM tests; prefer deleting a parallel path over abstracting it.
- `git mv` for every relocation — preserve history.

### Module-system constraints (why the mechanics look the way they do)

- `lib.mkIf` **cannot** guard options that don't exist on a platform. Setting `services.flatpak.*` in a module evaluated on Darwin errors at eval even under `mkIf false`. Platform-only option namespaces need file-level gating, not `mkIf`.
- `imports` may depend on specialArgs (`isDarwin`, `host`) but never on `config`. So `imports = lib.optionals (!isDarwin) [./desktop];` is legal, while importing based on a profile toggle is not.
- `home-manager.sharedModules` is a regular *option* (not `imports`), so it **can** be set under `lib.mkIf cfg.enable`. This is what lets a profile own its HM half (Phase 3).
- `environment.systemPackages` exists on both NixOS and nix-darwin — plain package lists are already cross-platform with `lib.optionals (!isDarwin) [...]` inline.

## Target profile structure (end state)

The structure all phases work toward. The litmus test for where something belongs: **"does mini need it?"** — baseline profiles stay on for the server; everything workstation-flavored is a separate toggle the server opts out of.

```text
modules/profiles/
├── default.nix             # ALL option declarations + server-class assertions
│                           #   + Linux-only leaf imports (lib.optionals (!isDarwin) [...])
│
│ # ── always-on baseline (enableOn, default true — mini keeps all of these) ──
├── minimal.nix             # system core, sandbox-safe shells, daily-driver CLIs
├── essentials.nix          # prompt, HM widgets, system env, Nix workstation tooling
├── fonts/
│   ├── default.nix         # minimal set: Iosevka NF, Iosevka Etoile, Inter, Noto emoji
│   └── full.nix            # fonts.full.enable — merged catalogue; mini opts out
├── theme/
│   ├── default.nix         # theme: Stylix + Birds-of-Paradise base16 + CLI/shell theming
│   ├── home.nix            #   HM half via sharedModules (terminal/prompt/CLI colors)
│   └── gui.nix             # theme.gui.enable — wallpaper, cursor, opacity, GTK/Qt,
│                           #   zen target, Pictures/Wallpapers symlinks; mini opts out
│
│ # ── opt-in feature profiles ──
├── apps/                   # apps.* — feature folders owning system + home.nix halves
│   ├── notes/              #   (Phase 3 pattern: sharedModules under mkIf)
│   └── ...
├── devenv/                 # devenv.enable — headless dev core, SSH-safe (Phase 6);
│   ├── tools.nix           #   separated by tool area, each category sub-enable
│   ├── cloud.nix           #   mkDefault-follows the parent
│   ├── containers.nix      #   podman + TUIs (CLI only)
│   ├── databases.nix       #   rainfrog (TUI only)
│   ├── agents.nix          #   agent CLIs (was devenv.llm.agents)
│   └── languages/          #   devenv.languages.<name>.enable
├── devgui/                 # devgui.enable — GUI dev tooling; mirrors devenv's
│   ├── ides.nix            #   category names: cursor + zed (from apps.editors)
│   └── containers.nix      #   podman-desktop; no file for categories without
│                           #   GUI members
├── llm/                    # llm.enable — lmstudio/llama.cpp serving stack,
│                           #   extracted from devenv (Phase 6); default off
├── work/                   # work.enable — default.nix + darwin.nix (homebrew leaf)
├── server.nix              # server.enable
│
│ # ── Linux-only leaves (imported when !isDarwin) ──
├── desktop/                # niri + DMS + greeter
├── gaming.nix              # Steam stack
└── integrations.nix        # AppImage + Flatpak
```

Per-host toggle matrix (end state; `—` = Linux-only, no effect on Darwin):

| Profile | default | desktop | framework | caya | mini (server) |
| --- | --- | --- | --- | --- | --- |
| `minimal`, `essentials` | on | on | on | on | on |
| `fonts` (minimal set) | on | on | on | on | on |
| `fonts.full` | on | on | on | on | **off** |
| `theme` (CLI/shell) | on | on | on | on | on |
| `theme.gui` | on | on | on | on | **off** |
| `apps` | off | on | on | on | off |
| `devenv` (headless core) | off | on | on | on | on |
| `devgui` | off | on | on | on | off |
| `llm` | off | on\* | off | on\* | on (per host fact) |
| `work` | off | off | off | on | off |
| `desktop` | on | on | on | — | **off** |
| `integrations` | on | on | on | — | **off** |
| `gaming` | off | on | off | — | off |
| `server` | off | off | off | off | **on** |

\* "on" preserves today's *effective* state — `devenv.enable` currently mkDefault-enables `devenv.llm.hosting` everywhere, so desktop and caya have a serving stack (lmstudio) on right now without ever asking for it. At migration, decide per host whether that was intended; dropping it there is a deliberate closure reduction, not a regression.

Conventions:

- Workstation-flavored profiles use `enableOn` (default true); the server opts out explicitly in `hosts/mini/profiles.nix`, matching its existing "headless: opt out of every desktop-flavoured profile" style.
- The server-class assertion list in `default.nix` grows to cover every workstation-flavored toggle: today's `desktop`, `apps`, `integrations`, `gaming`, `work` plus the new `fonts.full`, `theme.gui`, and `devgui`.
- A profile that needs an HM half owns it as a `home.nix` pushed through `home-manager.sharedModules` — no `osConfig` lookups from `home/`.
- End state for `home/`: dissolved into the feature folders above (Phase 7, tiered); HM config reaches users exclusively via `sharedModules`, and the `home/shared`/`home/nixos`/`home/darwin` platform split disappears the same way the modules one did.

## Phase 1 — Thin `flake.nix`, dedupe packages, input hygiene, de-leak the host factory

Problem: `flake.nix` hand-imports 6 of the 8 `packages/*` that `parts/overlays/local-packages.nix` already auto-registers (and inconsistently omits `oh-my-pi`). `parts/hosts.nix` carries mini-only logic (`hostKey == "mini"` gating for llama-cpp) and imports `hermes-agent` and `disko` modules for every Linux host although only mini uses them. One input is wired to nothing it should be (`skills-mattpocock`), one looks dead but isn't (`corecycler`).

Plan:

1. Move the `perSystem` block out of `flake.nix` into `parts/packages.nix` and `parts/checks.nix`. Target root:

   ```nix
   outputs = inputs @ {flake-parts, ...}:
     flake-parts.lib.mkFlake {inherit inputs;} {
       imports = [
         ./parts/hosts.nix
         ./parts/shells.nix
         ./parts/packages.nix
         ./parts/checks.nix
       ];
       systems = ["x86_64-linux" "aarch64-darwin"];
     };
   ```

2. Single package exposure mechanism: `parts/packages.nix` derives the name list the same way `local-packages.nix` does (readDir over `packages/` + the per-package system filter) and exposes `perSystem.packages.<name> = pkgs.<name>`. All 8 packages exposed; `framework-control` stays gated to `x86_64-linux`. No more per-package import boilerplate anywhere.
3. Input hygiene:
   - `corecycler`: keep, add a `# kept but currently disabled — <bug ref>` comment in `flake.nix` so it doesn't read as dead.
   - `skills-mattpocock`: make it the actual source for `just skills-upstream`. Expose `flake.lib.skillsUpstreamSrc = inputs.skills-mattpocock.outPath;` and change `scripts/shell/skills-upstream.bash` to `UPSTREAM_DIR="$(nix eval --raw "$FLAKE#lib.skillsUpstreamSrc")/skills"`. The `~/Git/skills` clone dependency goes away; the pin updates via `just update`. Update the README input table.
4. De-leak `parts/hosts.nix`: move the mini-only module imports into `hosts/mini/default.nix`, which already uses exactly this conditional-import pattern (`lib.optionals (!bootstrap && miniLlmHosting) [...]`):
   - `inputs.disko.nixosModules.disko` (disko is referenced only by mini),
   - `inputs.hermes-agent.nixosModules.default` (alongside the existing `./hermes.nix`),
   - `inputs.llama-cpp-nix.nixosModules.default` plus its `hostKey == "mini"` gate (merge into the existing `./llm/llama-cpp.nix` optional).
   The factory keeps only modules genuinely common to all hosts of a platform (stylix, dms, sops, determinate, lanzaboote, home-manager).

Acceptance:

- Root `flake.nix` contains inputs and flake-parts wiring only.
- `nix eval` of `packages.<system>` shows all local packages, no duplication with the overlay.
- `parts/hosts.nix` contains no `hostKey == "..."` conditionals and no single-host module imports.
- `just skills-upstream` works without `~/Git/skills`.
- `flake build-dry` passes for the active host; `flake switch-check` passes.

## Phase 2 — Merge the profile trees into `modules/profiles/`

Problem: profile content lives in two parallel hierarchies (`modules/shared/profiles/` + `modules/nixos/profiles/`) plus a hidden third place (the Homebrew block in `modules/darwin/default.nix` gated on `work.enable`). This forces empty placeholder files (e.g. `modules/shared/profiles/apps/notes.nix` whose only content is a comment pointing elsewhere) and an external index (`docs/profiles.md`) to navigate.

Plan:

1. `git mv modules/shared/profiles modules/profiles`. Option declarations and the server-class assertions in its `default.nix` move as-is — they are already centralized and correct.
2. Fold `modules/nixos/profiles/` in:
   - `apps/*` fragments that are plain package lists merge inline into the matching `modules/profiles/apps/<name>.nix` with `lib.optionals (!isDarwin) [...]` (e.g. notes gains libreoffice on Linux; terminals gains alacritty/ghostty/kitty on Linux).
   - `desktop.nix`, `gaming.nix`, `integrations.nix` use NixOS-only option namespaces → they move as Linux-only leaves, imported from `modules/profiles/default.nix` via `imports = lib.optionals (!isDarwin) [./desktop ./gaming.nix ./integrations.nix];`.
3. Move the `work.enable`-gated Homebrew block from `modules/darwin/default.nix` to `modules/profiles/work/darwin.nix`, imported when `isDarwin`. `modules/darwin/` shrinks to platform base only (`nix.enable = false`, fonts).
4. Each host adds `../../modules/profiles` to its imports; `modules/shared` and `modules/nixos` stop importing profile content. After this, `modules/{shared,nixos,darwin}` hold **unconditional platform base** only (boot, networking, gc, sops, user, shells, fonts, environment).
5. Delete the placeholder files. Shrink `docs/profiles.md` to a one-paragraph pointer (the tree is now its own index). Update the "Where to Put Things" table in `modules/AGENTS.md`.

Target shape:

```text
modules/
├── profiles/                 # ONE tree — all profile content
│   ├── default.nix           # options + assertions + platform-leaf imports
│   ├── minimal.nix
│   ├── essentials.nix
│   ├── apps/
│   │   ├── notes.nix         # shared + lib.optionals platform extras, one file
│   │   └── ...
│   ├── devenv/...
│   ├── work/                 # default.nix + darwin.nix (homebrew leaf)
│   ├── desktop/              # Linux-only leaf
│   ├── gaming.nix            # Linux-only leaf
│   └── integrations.nix      # Linux-only leaf
├── shared/                   # platform base: environment, shells, security (fonts → Phase 4)
├── nixos/                    # platform base: boot, networking, gc, sops, user, …
└── darwin/                   # platform base: nix.enable=false (fonts → Phase 4)
```

Acceptance (behavioral, not structural):

- Before/after diff of `nix eval .#nixosConfigurations.<host>.config.environment.systemPackages --apply 'map (p: p.name)'` is empty for each Linux host; same for `darwinConfigurations.caya`.
- `flake switch-check` passes; `flake build-dry` passes on Linux and Darwin.
- No file under `modules/profiles/` is an empty placeholder.

## Phase 3 — Feature-folder pilot (notes) + eval-only checks

### 3a. Pilot: profile owns its HM half

Problem: even after Phase 2, a profile-gated app keeps its HM config in a separate tree (`home/shared/apps/...`), gated by an `osConfig.dotfiles.profiles...` lookup — the last axis of fragmentation.

Plan: pilot on `apps.notes` only.

```text
modules/profiles/apps/notes/
├── default.nix   # system pkgs + home-manager.sharedModules = lib.mkIf cfg.enable [./home.nix];
└── home.nix      # programs.obsidian — current home/shared/apps/notes, osConfig gate removed
```

`git mv` the HM file from `home/shared/apps/notes/`; delete its entry from the `home/` import chain. Guest users (`extraUsers`) already receive the same HM modules, so `sharedModules` is behavior-preserving.

Decision gate: live with it for a while. If it reads better, the pilot pattern becomes the vehicle for dissolving `home/` (Phase 7, tiered). If it doesn't, revert the pilot and stop; Phase 2 already removed most of the pain.

Acceptance:

- `nix eval .#nixosConfigurations.framework.config.home-manager.users.<user>.programs.obsidian.enable` is `true` with the profile on, and the option is absent/false with the profile off.
- `home/shared/apps/notes/` no longer exists; no `osConfig` reference remains for notes.

### 3b. Eval-only checks in `parts/checks.nix`

Plan:

1. Keep `tests/mcp-servers.nix` as-is.
2. Add a Darwin eval check — the one real coverage gap, since `nix flake check` ignores `darwinConfigurations`. An eval-only check forces `darwinConfigurations.caya.config.system.build.toplevel.drvPath` (discard string context so nothing gets built).
3. Add at most 2–3 profile-interaction eval assertions where regressions are plausible (e.g. server-class host evaluates with desktop/apps/gaming off — mini covers this for free via flake check; a workstation evaluates with a profile toggled off). No `nixosTest` VM tests — building a full host closure and booting a VM is disproportionate for a personal flake and can't run from the Mac.

Acceptance:

- `flake switch-check` fails if the Darwin host stops evaluating.
- Checks assert behavior (evaluates / option resolves), never that a config option equals its current default.

## Phase 4 — Fonts profile (pilot for promoting unconditional base content into profiles)

Problem: fonts are unconditional platform base today, and doubly so. Every host — including the `mini` server — gets:

- `modules/shared/fonts.nix`: ~70 font packages at system level (`fonts.packages`), and
- `home/shared/assets/fonts/`: a second 64-font catalogue installed per-user via HM `home.packages` on Linux and re-exported into nix-darwin `fonts.packages` by `modules/darwin/fonts.nix`, carried by two helper files (`install.nix` with a Darwin woff-layout workaround, `enabled-packages.nix` flattening).

The two lists overlap heavily (fira-code, jetbrains-mono, cascadia, iosevka, maple-mono, …). On top of that:

- `home/shared/assets/icons/nerdfonts.nix` (33.5k lines) has zero consumers — dead.
- The catalogue imports iosevka-aile/etoile via `../../../../packages` relative paths although the overlay already exposes `pkgs.iosevka-aile` / `pkgs.iosevka-etoile`.
- Latent gap: Stylix sets `sansSerif.name = "Inter Variable"` with **no package** — it only renders because the catalogue happens to install `inter`.

Plan:

1. Delete `home/shared/assets/icons/nerdfonts.nix`.
2. One install mechanism: `fonts.packages` exists on **both** NixOS and nix-darwin, so the profile sets it inline with no platform leaf. Delete `install.nix` (and its Darwin workaround), `enabled-packages.nix`, the `modules/darwin/fonts.nix` re-export, and the HM font path entirely. The catalogue's `name`/`style` metadata only feeds a debug `fonts-installed.txt` — drop it; the catalogue flattens to plain package lists.
3. Profile shape:

   ```text
   modules/profiles/fonts/
   ├── default.nix   # options + minimal set (always on)
   └── full.nix      # merged + deduped catalogue, gated on fonts.full.enable
   ```

   - **Minimal** (always on) = exactly what Stylix references: `nerd-fonts.iosevka`, `iosevka-etoile`, `inter`, `noto-fonts-color-emoji`. Guaranteed present wherever Stylix renders — fixes the Inter gap. The server gets only these.
   - **`fonts.full.enable`** follows the existing convention: `enableOn` (default true), `hosts/mini/profiles.nix` disables it, and it joins the server-class assertion list in `profiles/default.nix`.
   - Iosevka packages come from `pkgs.<name>` via the overlay — no relative imports.
4. While merging the two lists into `full.nix`, prune deliberately: a font kept must be referenced by Stylix, an app config, or actually used in a terminal — record drops in the commit message. Don't silently keep all ~90 unique fonts.

Surveyed alongside fonts:

- **Theming** is the same pattern and gets its own phase → Phase 5.
- **Already gated, no action**: `modules/nixos/virtualization.nix` looks unconditional but is internally gated on `devenv.containers.enable` (the podman *service* is headless — it stays a `devenv` category in Phase 6).

Acceptance:

- A workstation's font set is the previous union minus deliberately pruned fonts; mini's closure drops the full font set.
- `assets/fonts/install.nix`, `enabled-packages.nix`, and `nerdfonts.nix` no longer exist; no `osConfig`/HM font install path remains.
- Darwin still receives fonts via nix-darwin `fonts.packages` from the same profile files.
- `flake switch-check` passes; `flake build-dry` passes on Linux and Darwin.

## Phase 5 — Theme profile (Stylix split: CLI everywhere, GUI for workstations)

Problem: the Stylix HM config (`home/shared/assets/theme/stylix.nix`) is unconditional. The server only needs CLI/shell theming, but today it also receives the wallpaper image, `phinger-cursors`, opacity settings, and GUI target config. One implicit profile toggle already hides in there: `targets.gtk.enable = lib.mkDefault (isDarwin || (host ? mainMonitor))` — an ad-hoc host-fact gate doing what a profile option should.

Plan:

1. `modules/profiles/theme/{default.nix,home.nix,gui.nix}` using the Phase 3 `sharedModules` pattern.
2. **Base** (`theme`, `enableOn`, stays on for mini): `stylix.enable`, the Birds-of-Paradise `base16Scheme` from `theme.nix`, `polarity`, the fonts block (packages via `pkgs.iosevka-etoile` etc. from the overlay — no more fonts-catalogue import), CLI/shell theming (prompt, bat/fzf, terminal colors).
3. **GUI** (`theme.gui.enable`, `enableOn`, mini opts out): `image`/wallpaper, `cursor` (`phinger-cursors`), `opacity`, GTK/Qt, zen-browser/kitty target tweaks, plus the `Pictures/Images` + `Pictures/Wallpapers` symlinks from `assets/files.nix`. The `host ? mainMonitor` ad-hoc gate is replaced by `theme.gui.enable`.
4. `theme.nix` stays the single palette source (the Python mirror sync note in `home/AGENTS.md` is unchanged). `theme.gui` joins the server-class assertions; mini opts out in `profiles.nix`.

Depends on Phase 4 (the base fonts block references the minimal font packages).

Acceptance:

- mini's closure drops `phinger-cursors` and the wallpaper; its CLI colors are unchanged.
- Workstations render identically before/after.
- No `host ? mainMonitor` reference remains in theme config.

## Phase 6 — Split dev tooling into `devenv` / `devgui` / `llm`

Problem: `devenv` mixes three concerns that vary independently per host:

1. The **headless, SSH-safe dev core** (build/VCS tools, cloud CLIs, podman + TUIs, database TUIs, agent CLIs) — mini wants all of it.
2. **GUI dev tooling** — inside devenv proper that is exactly one package today (`podman-desktop`, which the `mkDefault` cascade currently puts in the headless server's closure), plus the cursor/zed IDE configs that hang off `apps.editors` even though they are dev tooling.
3. The **LLM serving stack** (`devenv.llm.hosting` — lmstudio/llama.cpp), which isn't a dev-environment concern at all and forces negations (`hosts/framework/profiles.nix`) and host-fact conditionals onto hosts that only wanted dev tools.

Plan — three top-level profiles:

1. **`devenv`** — the headless core, still separated by tool area: `tools`, `cloud`, `containers` (CLI/TUI only), `databases` (TUI), `agents` (renamed from `devenv.llm.agents`; the `devenv.llm.*` group dissolves), `languages.<name>`. Category sub-enables stay and keep `mkDefault`-following `devenv.enable` — per-host config remains one line, fine-grained opt-outs stay available (mini's `languages.swift` survives unchanged).
2. **`devgui`** — GUI dev tooling as its own top-level profile, mirroring devenv's category names so a tool area's GUI counterpart is always in the predictable place: `devgui.containers` (`podman-desktop` moves here), `devgui.ides` (cursor + zed HM configs re-gate here from `apps.editors`; helix is a terminal editor and stays in `apps.editors`). No files for categories without GUI members — no placeholders. Default off; workstations enable it; joins the server-class assertions.
3. **`llm`** — the serving stack: `dotfiles.profiles.llm.enable`, **default off**. `hosts/framework/profiles.nix` deletes its negation; `hosts/mini/profiles.nix` and the `mkForce` in `hosts/mini/services/llm/llama-cpp.nix` switch to the new path; desktop/caya opt in only if a serving stack there is actually wanted (see the matrix footnote — today it's on via `mkDefault` without anyone asking).
4. Chase the ripples: `rg 'devenv\.(llm|tools|cloud|containers|databases)'` — known consumers include `modules/nixos/virtualization.nix` (`devenv.containers`, unchanged — the podman service is headless), `parts/shells.nix`, and several `home/shared/development/tooling/*` files gating on `devenv.llm.agents` → now `devenv.agents`. Fix stale option descriptions while there (e.g. `databases` mentions dbeaver-bin, which isn't installed; if it ever returns it's `devgui.databases`).

Behavior-preservation note: workstations have both `apps` and `devenv` on, so moving IDE gating from `apps.editors` to `devgui.ides` changes nothing for them; mini already excluded the IDEs via `apps.enable = false`.

Acceptance:

- mini's closure **drops `podman-desktop`** while keeping podman, the agent CLIs, and the full tools set — verify via the systemPackages name diff.
- No `devenv.llm.*` options remain; `devgui` and `llm` exist as top-level profiles.
- All four hosts' package sets are otherwise unchanged except deliberate `llm` decisions, recorded in the commit message.
- `hosts/framework/profiles.nix` contains no negations.

## Phase 7 — Dissolve `home/` into the profile tree (tiered)

Problem: `home/` is the third parallel tree, with the same shape disease the modules merge cured — a `shared`/`nixos`/`darwin` platform split (~105 nix files) and `osConfig.dotfiles.profiles.*` gates pointing back at the profiles that conceptually own the config. End state: every profile owns its HM half as `home.nix`/`home/` inside its feature folder (pushed via `home-manager.sharedModules`), the `home/` directory is gone, and `parts/hosts.nix` no longer assembles per-platform `homeModules` lists.

One coupling makes this incremental by necessity: **7 files use `config.dotfiles.flakeRoot` live symlinks** (`mkOutOfStoreSymlink`) whose runtime targets point into `home/...` paths in the repo (`nixos/desktop/dms`, `shared/assets/files.nix`, `shared/agents.nix`, `shared/compat.nix`, `shared/dotfiles.nix`, `shared/shells/env/system.nix`, `shared/utils/television`). Moving those directories changes symlink targets on deployed machines — each such move needs the path updated, `just symlink-check` run, and any Justfile/script references chased. Hence tiers, each independently verified, rich worlds last.

Tiers (each gated on the previous one feeling right):

1. **Already planned elsewhere**: notes pilot (Phase 3a), fonts catalogue + dead icons (Phase 4), theme + wallpaper symlinks (Phase 5), IDE gating (Phase 6 `devgui.ides`).
2. **Small profile-gated apps** — HM configs of `terminals` (ghostty, kitty), `editors` (helix), `comms`, `media`, `files` move into their `modules/profiles/apps/<name>/home.nix`. One PR each. The `osConfig` gate disappears with each move (the profile pushes `home.nix` under `mkIf cfg.enable`).
3. **Dev tooling** — `home/shared/development/` (mcp-servers, agents-cli, nono-profiles HM side, …) becomes the home half of `devenv`/`devenv.agents`; pairs naturally with the Phase 6 split. `host-status`/`fastfetch` widgets go to `essentials`.
4. **Rich config worlds** — Zen → `apps/browsers/`, cursor/zed configs → `devgui/ides/`, `home/nixos/desktop` (niri/DMS session) → `desktop/`. This tier carries the live-symlink path updates (DMS settings, niri kdl) and the `data/`-vs-config decision for big non-nix assets.
5. **User baseline** — `home/shared/shells/` (18 files), `utils/`, `network/`, `security.nix`, `environment.nix` become home halves of `minimal`/`essentials`/`theme`; `home/darwin/` and `home/nixos/` leftovers dissolve into platform leaves of their owning profiles. `parts/hosts.nix` `homeModules` shrinks to nothing — HM config arrives exclusively via `sharedModules`. Guest users (`extraUsers`) receive `sharedModules` identically, so behavior is preserved.

Acceptance per tier:

- The moved app/config behaves identically (HM activation diff or targeted `nix eval` on the HM option).
- No `osConfig` reference remains for moved features; no `home/` path remains in live-symlink targets that moved.
- `just symlink-check` is clean after tiers that touch `flakeRoot` symlinks.
- After the final tier, `home/` does not exist and `homeManagerConfig` in `parts/hosts.nix` carries no platform-specific import lists.

## Keep as-is

- `hosts/hosts.nix` registry and validation; `parts/hosts.nix` host-output generation (post-Phase-1, host-agnostic).
- `dotfiles.profiles.*` as the host-facing switchboard; centralized option declarations.
- `lib/pkgs.nix` as the pkgs import policy.
- `packages/` with overlay auto-registration.
- Justfile and `scripts/` as the operator interface.
- `data/agents/` assets; Justfile symlink tooling (`just symlink-check`).

## Appendix — demoted ideas and their re-entry conditions

Carried over from the first draft; each was complexity-positive against this plan's goal. Revisit only when its condition actually occurs.

| Idea | Re-entry condition |
| --- | --- |
| Layer `hosts/<name>/` into `system/`, `home-manager/`, `tests/` | A test genuinely needs to import a host's system stack in isolation (eval-level checks don't — they use the existing host outputs). |
| `my.*`-style CLI wrapper framework | A CLI concretely needs baked config at system scope that Home Manager + profiles cannot express. Not before. |
| flake-parts partitions for input isolation | Input fetch/eval time measurably hurts after Phase 1's input hygiene. Partitions cost 2–3 sub-flakes with their own lockfiles and a changed update workflow — the bar is high. |
| `nixosTest` VM smoke tests | An eval-level check provably missed a regression class that a VM boot would have caught. |

## Non-goals

- No rewrite toward the example repository's layout.
- No wrapper framework, no partitions, no VM test harness (see appendix).
- No big-bang `home/` migration — it dissolves tier by tier (Phase 7), each tier independently verified; rich config worlds move last.
- No removal of the Justfile workflow.
- No hand-written host output list.
- No test that locks current defaults instead of behavior.
