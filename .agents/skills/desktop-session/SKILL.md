---
name: desktop-session
description: Apply this flake's Linux desktop session rules. Use it for changes to niri or Umbriel, Noctalia or DMS, the greeters, keybinds, window rules, or monitor outputs. Also use it for a desktop session file in the checkout that drifts from the flake.
---

# Desktop Session

## Scope

This skill covers the compositors, the shells, the login screens, and their per-host files in `modules/profiles/desktop/`. Other skills own these topics:

- Colors, palette mirrors, wallpapers, and the Noctalia configuration layers: `theme-structure`.
- MIME defaults, and app ids that the niri, Umbriel, and Noctalia files repeat: `xdg-default-apps`.
- Where a new module or file goes in `modules/profiles/`: `module-structure`.
- Expiry guards: `overlays`. The only guard here is the OpenLogi guard in `peripherals.nix`.

## Session map

Two options in `modules/profiles/default.nix` (the `desktop` block) select the session. Each host sets them in `hosts/<host>/profiles.nix`.

| Host | `desktop.shell` | `desktop.loginManager` |
| --- | --- | --- |
| desktop | `noctalia` | `noctalia-greeter` |
| framework | `noctalia` | `gdm` |
| option default | `dms` | `dms-greeter` |

- Every desktop host gets two compositor sessions: niri and Umbriel (`programs.umbriel`). The user selects one on the login screen. `services.desktopManager.gnome.enable` is always on. It adds a GNOME session and the GNOME apps.
- The shell runs in niri and in Umbriel. With `dms-greeter`, the DMS module starts DMS. With the other login managers, `gnome/home.nix` starts the shell as a user unit on `graphical-session.target`.
- The assertion in `desktop/default.nix` forbids `noctalia` with `dms-greeter`. No assertion covers the other pairs. The comment `# required for noctalia` in `hosts/framework/profiles.nix` is stale, because `noctalia-greeter` now exists.
- `gdm` enables `gnome/default.nix`. `noctalia-greeter` enables `noctalia/greeter.nix`. `dms-greeter` with DMS enables `programs.dms-greeter` and `dms/greeter-acl.nix`.
- `hosts/framework/input.nix` sets fingerprint PAM rules for `gdm` and `dms-greeter` only. Read it before you change the login manager of framework.
- Do not set the `host.desktopShell` registry field. `desktop/default.nix`, `niri-hm.nix`, `umbriel-hm.nix`, and `greeter-acl.nix` read it, but `gnome/home.nix` and `apps/editors/helix.nix` read only the option.

## Per-host files

A live symlink is a Home Manager link from your home folder to the file in the checkout. An edit to a linked file applies without a switch. A new file gets its link only after a switch, because the link list comes from `builtins.readDir`.

| Area | File in `modules/profiles/desktop/` | How the host selects it | Link |
| --- | --- | --- | --- |
| niri outputs | `niri/outputs-<host>.kdl` | `niriOutputsFile` in `hosts/<host>/host.nix`. If it is not set, `host.kdl` is a stub. | `~/.config/niri/host.kdl` |
| niri shell | `niri/shell-<shell>.kdl`, which includes `keybinds-<shell>.kdl` | `noctalia`, else `dms` | `~/.config/niri/shell.kdl` |
| Umbriel outputs | `umbriel/outputs-<host>.toml` | The host key. No registry field. A missing file is skipped. | `~/.config/umbriel/host.toml` |
| Umbriel shell | `umbriel/shell-noctalia.toml` | Noctalia only. DMS has no Umbriel binds. | `~/.config/umbriel/shell.toml` |
| DMS | `dms/config/settings-<host>.json` | `dmsSettingsFile`. The default is `settings-desktop.json`. | `~/.config/DankMaterialShell/settings.json` |
| Noctalia | `noctalia/config/settings.toml` | `noctaliaSettingsFile`. No host sets it, so desktop and framework share one file. | `~/.local/state/noctalia/settings.toml` |
| GDM | `gnome/monitors-<host>.xml` | `gdmMonitorsFile`, used only with `gdm`. Only desktop sets it, and desktop does not use `gdm` today. | `/var/lib/gdm/seat0/config/monitors.xml`, a store copy (not live) |

The other files in `niri/` and `umbriel/` are linked under their own names. A new file does nothing until an include names it. `niri/keybinds-overrides.kdl` is linked, but no file includes it.

Include order, where a later value wins:

- niri `config.kdl` includes `window-rules.kdl`, `keybinds-default.kdl`, `shell.kdl`, `host.kdl`, and `dither-glitch.kdl`. A shell bind replaces a default bind with the same keys.
- Umbriel `config.toml` includes `window-rules.toml` and `keybinds.toml`, then the optional `shell.toml`, `host.toml`, and `noctalia.toml`. The values in `config.toml` win over all includes. For this reason, put per-host keys (`layout.extent_presets`, `colors.border.unfocused`) only in `outputs-<host>.toml`.

To add a host:

1. Set `desktop.shell` and `desktop.loginManager` in `hosts/<host>/profiles.nix`.
2. Create `niri/outputs-<host>.kdl` and set `niriOutputsFile` in `hosts/<host>/host.nix`.
3. Create `umbriel/outputs-<host>.toml`. Use the host key from `hosts/hosts.nix` in the name. Set the two per-host keys above.
4. If the host runs DMS, create `dms/config/settings-<host>.json` and set `dmsSettingsFile`. If you do not, the DMS GUI writes into the desktop file.
5. If the host uses `gdm` with more than one display, create `gnome/monitors-<host>.xml` and set `gdmMonitorsFile`.
6. Run `git add` on the new files. Then ask the user to switch.

To add or change an output:

1. Get the name from `niri msg outputs` or `umbriel outputs` on the host that has the display.
2. In niri and Umbriel, match outputs by "make model serial", never by connector. On desktop, the connector names change with the GPU driver load order. Commit `6b3811ec` replaced connector names and `A || B` fallbacks for this reason.
3. Put the output block and every rule that names an output (`open-on-output`, `default_output`) in `outputs-<host>.*`. Do not copy the old `open-on-output "DP-2"` rule in `niri/window-rules.kdl`.
4. Noctalia keys its bar, dock, wallpaper, and lockscreen blocks by connector. For desktop, keep one block for each connector variant (`DP-1` and `DP-2`, `HDMI-A-1` and `HDMI-A-2`).
5. The GDM file uses mutter connector names (`HDMI-1`, not `HDMI-A-1`), integer scales, and one `<configuration>` for each cabling. Read the header of `gnome/monitors-desktop.xml`.

## niri and Umbriel parity

The Umbriel files are ports of the niri files. Their header comments name the features that Umbriel does not have.

- `niri/config.kdl` maps to `umbriel/config.toml`.
- `keybinds-default.kdl` maps to `keybinds.toml`. `[keybinds]` replaces the built-in Umbriel bind set.
- `shell-noctalia.kdl` and `keybinds-noctalia.kdl` map to `shell-noctalia.toml`.
- `window-rules.kdl` maps to `window-rules.toml`. `outputs-<host>.kdl` maps to `outputs-<host>.toml`.

If you change a bind, a rule, or an output on one side, make the same change on the other side. If Umbriel has no equivalent, tell the user. In Umbriel rules, follow these comments in `umbriel/window-rules.toml`:

- Set no `opacity`, except for YouTube Music and KDE Connect. Umbriel draws the border at the rule opacity.
- All match fields in one rule must match. For "A or B", write two rules.
- After a change to `[environment]` or `xwayland_native_resolution`, the user must restart Umbriel.

## Runtime writes and drift

These apps write through the live links into the checkout:

- The Noctalia GUI writes `noctalia/config/settings.toml`. Wallpaper automation (`interval_seconds = 600`) rewrites the `wallpaper.default`, `wallpaper.last`, and `wallpaper.monitors.*` paths every 10 minutes. Most `noctalia: settings` commits contain only that. One save can also bump `config_version` and rewrite hundreds of lines (`41aa7a47`).
- The DMS GUI writes `dms/config/settings-<host>.json`.
- If `noctalia.toml` is not the last optional include, the Noctalia Umbriel template rewrites `umbriel/config.toml`. Templates are off today (`enable_builtin_templates = false`).

Before a commit, follow these rules:

1. Run `git status --short modules/profiles/desktop` and read the `git diff` of each file above.
2. Show the user each runtime-written diff and name the keys that changed. Do not stage or commit it without the approval of the user. Never put it in an unrelated commit.
3. Do not run `git checkout` or `git restore` on a runtime-written file. That deletes the GUI changes of the user.
4. If the user keeps the change, commit it alone. Name the change in the message (`noctalia: Almond blossom wallpaper`), not `noctalia: settings`.
5. A GUI save on one host changes the shared `settings.toml` for both hosts.
6. `settings.toml` holds absolute paths (`/home/jadee/Pictures/...`, `~/git/community-plugins`). If you move a folder, update them (`31e4d5df`).

`just symlink-check` runs `symlink-check all` from `scripts/src/flake_scripts/symlinks.py`:

- It lists `~/.config/DankMaterialShell`, `~/.local/state/noctalia/settings.toml`, `~/.config/niri`, and `~/.config/quickshell/config.kdl`. It reports a regular file, a missing target, or a store hop. It always exits 0.
- It also reports every unlinked file in those folders, for example DMS state files and `config.kdl.*backup*`. These files are not drift.
- The Noctalia link always shows a store hop. `directFlakeSymlinks` in `lib/home/dotfiles.nix` does not repoint `~/.local/state`. If the target is in the checkout, the hop is harmless. The quickshell row expects `dms/config/config.kdl`, which does not exist.
- If `DankMaterialShell/settings.json` does not resolve into `dms/config/` or is not writable, `just symlink-check-dms` exits 1. `uv run --project scripts symlink-check noctalia-settings` is the same test for Noctalia. It has no recipe, and the store hop makes it exit 1.
- No mode looks at `~/.config/umbriel`, at file content, or at git. For Umbriel, run `ls -l ~/.config/umbriel` and make sure that each entry points into the checkout.

## Hazards from module comments

- `noctalia/default.nix`: do not feed `settings.toml` into `programs.noctalia.settings` (see `theme-structure`). Do not import the Noctalia `homeModules.default`, because Home Manager declares `programs.noctalia` already.
- `noctalia/default.nix`: an app that saves with write-temp-then-rename replaces a live link with a plain file. `symlink-check` then reports a regular file.
- `gnome/home.nix`: do not add `Environment=PATH=...` to the `noctalia` unit. systemd does not expand `$PATH` there, and the session buttons stop working.
- `gnome/default.nix`: GDM 49 and later reads the greeter configuration only from `/var/lib/gdm/<seat>/config`.
- `dms/greeter-acl.nix` contains the path `~/git/flake`, not `dotfiles.flakeRoot`. If the checkout moves, update it (`0b9766b7`).
- `desktop/default.nix`: keep `handy` from nixpkgs, not llm-agents (the window stays blank). Keep `KITTY_WAYLAND_DETECT_MODIFIERS`, because the herdr Hyper prefix needs it.

## Test the change

Never build or switch yourself (see `AGENTS.md`).

1. Run `niri validate` and `umbriel config validate`. Both read the live links, so they test your edit without a switch.
2. Run `noctalia config validate modules/profiles/desktop/noctalia/config/settings.toml`.
3. After `.nix` edits, run `flake fmt`. Run `git add` on new files.
4. To read one value, evaluate one attribute: `nix eval --json .#nixosConfigurations.framework.config.dotfiles.profiles.desktop.loginManager`.
5. Run `just symlink-check` and read the Noctalia, DMS, and niri rows.
6. Ask the user to switch after a new file, a `.nix` change, or a greeter change. Then ask the user to log in to each changed session.
