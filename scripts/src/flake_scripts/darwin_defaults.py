#!/usr/bin/env python3
"""Capture macOS defaults into the flake (check + sync).

Two generated modules, both consumed by Home Manager `targets.darwin.defaults`:

* `modules/profiles/minimal/darwin/defaults.generated.nix` — curated Apple
  domains covering the System Settings surface.
* `modules/profiles/work/darwin/brew-casks/defaults.generated.nix` — prefs for
  apps installed as Homebrew casks, discovered from the live cask list.

macOS has no registry of factory defaults, so "modified from default" is
approximated the way macOS itself records it: a key only appears in a user
preference domain once something has written it. The accuracy of that proxy
rests entirely on filtering out daemon and UI state, which is what the deny
lists below do. Domains configured by hand elsewhere in the flake are skipped,
so a generated module never fights a hand-owned one for the same domain.
"""

from __future__ import annotations

import argparse
import difflib
import plistlib
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from flake_scripts.lib.common import bad, info, resolve_flake_root, warn

_FLAKE_ROOT = resolve_flake_root(anchor=Path(__file__))
_SYNC_TOOL = "darwin-defaults"

_APPLE_REL = Path("modules/profiles/minimal/darwin/defaults.generated.nix")
_BREW_REL = Path("modules/profiles/work/darwin/brew-casks/defaults.generated.nix")

# Apple domains behind System Settings panes. Curated on purpose: a scan of all
# ~380 live domains showed the overwhelming majority hold only daemon state
# (CloudKit tokens, analytics counters, Biome bookmarks), so an allowlist beats
# any amount of filtering applied to everything.
APPLE_DOMAINS: tuple[str, ...] = (
    # Appearance, keyboard, text input, measurement units
    "NSGlobalDomain",
    # Desktop & Dock, Mission Control, hot corners. `com.apple.spaces` is
    # deliberately absent: it holds only per-display/per-space UUID layout.
    "com.apple.dock",
    "com.apple.WindowManager",
    # Finder and desktop services
    "com.apple.finder",
    "com.apple.desktopservices",
    # Control Centre / menu bar
    "com.apple.controlcenter",
    "com.apple.menuextra.clock",
    # Notifications and sound
    "com.apple.ncprefs",
    "com.apple.sound.beep",
    "com.apple.ComfortSounds",
    # Trackpad, mouse, keyboard shortcuts, input sources
    "com.apple.AppleMultitouchTrackpad",
    "com.apple.driver.AppleBluetoothMultitouch.trackpad",
    "com.apple.AppleMultitouchMouse",
    "com.apple.driver.AppleBluetoothMultitouch.mouse",
    "com.apple.driver.AppleHIDMouse",
    "com.apple.symbolichotkeys",
    "com.apple.HIToolbox",
    # Accessibility. `com.apple.Accessibility` is deliberately absent: it is the
    # accessibility daemon's mirror (every toggle present at its factory value,
    # plus connected-Braille-device state), and the writable surface behind the
    # System Settings pane is `com.apple.universalaccess`.
    "com.apple.universalaccess",
    # Screenshots, screen saver, Spotlight
    "com.apple.screencapture",
    "com.apple.screensaver",
    "com.apple.Spotlight",
    # Privacy, software update, System Settings itself
    "com.apple.AdLib",
    "com.apple.SoftwareUpdate",
    "com.apple.systempreferences",
    # Safari ships with macOS and is configured from its own settings window
    "com.apple.Safari",
)

# Keys that record state rather than intent, matched with `re.search` against
# the key name.
_DENY_KEY_PATTERNS: tuple[str, ...] = (
    # Cocoa window/toolbar/panel autosave state
    r"^NSWindow ",
    r"^NSToolbar",
    r"^NSSplitView",
    r"^NSTableView",
    r"^NSOutlineView",
    r"^NSNavPanel",
    r"^NSColorPanel",
    r"^NSStatusItem",
    r"^NSWindowTabbing",
    r"^NavPanel",
    r"^FK_",
    r"^__",
    r"WindowLocation",
    r"(?i)window\.location",
    r"ProgressWindow",
    r"(?i)geometry",
    r"(?i)window(frame|position|size)",
    r"(?i)^window(height|width)$",
    r"(?i)disclosedstate$",
    r"(?i)lastselection",
    r"(?i)collapsed",
    # CloudKit / sync / account plumbing
    r"CKStartupTime",
    r"(?i)cloudkit",
    r"(?i)subscription",
    r"(?i)zonecreated",
    r"(?i)recordzone",
    r"(?i)altdsid",
    r"(?i)syncstate$",
    r"(?i)loggedin",
    # Timestamps, counters, caches, analytics
    r"(?i)lastcheck",
    r"(?i)lastupdate",
    r"(?i)lastsync",
    r"(?i)lastused",
    r"(?i)lastsession",
    r"(?i)^last[-_]",
    r"(?i)heartbeat",
    r"(?i)timestamp",
    r"(?i)[-_]stamp$",
    r"(?i)cache",
    r"(?i)analytics",
    r"(?i)engagement",
    r"(?i)metrics",
    r"(?i)telemetry",
    r"(?i)diceroll",
    r"(?i)count$",
    r"(?i)countkey$",
    r"_bitfield$",
    # A stored absolute time (`timerEndInterval`, `…RequestLastInterval`) rather
    # than a duration anyone chose.
    r"(?i)interval$",
    r"(?i)^starttime$",
    r"_UpdateInfo$",
    # Migration / first-run / onboarding bookkeeping
    r"(?i)migrat",
    r"(?i)upgraded",
    r"^SU",
    r"(?i)version$",
    r"^Did[A-Z]",
    r"(?i)hasseen",
    r"(?i)hasdisplayed",
    r"(?i)haslaunched",
    r"(?i)hasrunbefore",
    r"(?i)hasrequested",
    r"(?i)^showed",
    r"(?i)notified",
    r"(?i)transitioncomplete",
    r"(?i)upgradelevel",
    # Case-sensitive on purpose: `(?i)fte` also matches "after…".
    r"FTE",
    r"(?i)education$",
    r"(?i)onboard",
    r"(?i)terminatedwith",
    r"(?i)crashed",
    # AuthKit account-state mirrors (AKLastLocale duplicates AppleLocale)
    r"^AK[A-Z]",
    # Identifiers and per-machine handles
    r"(?i)uuid",
    r"(?i)guid",
    r"(?i)deviceid",
    r"(?i)displayid$",
    r"(?i)userid$",
    r"(?i)installid",
    r"(?i)sessionid",
    r"(?i)persistent-id$",
    r"(?i)bookmark$",
    # Recents / MRU
    r"(?i)recent",
    r"(?i)mrulist",
    # AppKit/Electron boilerplate: written by the framework on first launch, not
    # by a user. Shows up identically in every Electron cask (Slack, Notion,
    # Claude, 1Password), where it is the entire contents of the domain.
    r"^AppleTextDirection$",
    r"^NSForceRightToLeftWritingDirection$",
    r"^NSFullScreenMenuItemEverywhere$",
    r"^NSTreatUnknownArgumentsAsOpen$",
    r"^NSAutoFillHeuristicsEnabled$",
    r"^NSInitialToolTipDelay$",
    # Marker the multitouch drivers set once a user-prefs plist exists at all.
    r"^UserPreferences$",
    # Update-check bookkeeping, per-install counters, session state
    r"(?i)^latest",
    r"(?i)^last[A-Z_-]",
    r"(?i)^persisted",
    r"(?i)^launched$",
    r"(?i)^ever[A-Z]",
    r"(?i)counter$",
    r"(?i)history",
    r"(?i)^uid$",
    # Crash/update/telemetry SDK noise commonly found in cask apps
    r"MSAppCenter",
    r"(?i)^sparkle",
    r"(?i)crashlytics",
    r"(?i)sentry",
    r"(?i)amplitude",
    r"(?i)mixpanel",
    r"(?i)posthog",
)

# Keys that may hold credentials. These generated modules are committed, so
# this list is a safety rule rather than a noise rule: it is applied even under
# `--include-state-keys`. Real example that motivated it — Shottr keeps a
# `kc-vault` blob and an S3 `token` in its preference domain.
_SECRET_KEY_PATTERNS: tuple[str, ...] = (
    r"(?i)vault",
    r"(?i)secret",
    r"(?i)password",
    r"(?i)passwd",
    r"(?i)credential",
    r"(?i)token",
    r"(?i)api[-_]?key",
    r"(?i)access[-_]?key",
    r"(?i)private[-_]?key",
    r"(?i)client[-_]?id",
    r"(?i)auth",
    r"(?i)cookie",
    r"(?i)keychain",
)

# Domain-scoped noise too specific to justify a global pattern.
_DENY_DOMAIN_KEYS: dict[str, tuple[str, ...]] = {
    "com.apple.finder": (
        r"^Bulk",
        # Per-window/per-tag saved view state, incl. `ViewSettingsDictionary`
        # and the `<Folder>ViewSetting` entries.
        r"(?i)viewsettings?",
        r"^FXDesktopVolumePositions$",
        r"^FXInfoPanes",
        r"^FXInfoWindow",
        # iCloud provider handles and the last-used (not default) search scope.
        r"^FXDetached",
        r"^FXLast",
        r"^FXSyncExtension",
        r"^GoToField",
        r"^SearchRecents",
        r"^TagsCloudSerialNumber$",
        # Set because the machine has no optical drive, not because anyone said so.
        r"^ProhibitBurn$",
        # Sidebar and pane sizes: window chrome, not preferences.
        r"^SidebarWidth",
        r"Width$",
        r"^SidebarShowing",
        r"^CopyProgressWindow",
    ),
    "com.apple.dock": (
        # Dock tile contents are opaque bundle blobs, not settings.
        r"^persistent-apps$",
        r"^persistent-others$",
        r"^recent-apps$",
        r"^region$",
        r"^loc$",
        # Whether the Trash currently has something in it.
        r"^trash-full$",
    ),
    "com.apple.Safari": (
        r"^ResetCloudHistory$",
        r"^DownloadsPath$",
    ),
    "com.apple.WindowManager": (r"^GloballyEnabledEver$",),
    "com.apple.AdLib": (
        # Server-assigned ad segment endpoint, not a privacy setting.
        r"^partiality-segment$",
    ),
    "NSGlobalDomain": (
        r"^AppleLanguagesDidMigrate$",
        r"^NSLinguisticDataAssets",
        r"^com\.apple\.springing\.",
        r"^NSOSPLastRootDirectory$",
        # Finder's per-provider sync maps, empty on a machine without them.
        r"^com\.apple\.finder\.SyncExtensions$",
    ),
    "com.apple.HIToolbox": (
        # The layout active right this second; `AppleEnabledInputSources` and
        # `AppleSelectedInputSources` are the configuration.
        r"^AppleCurrentKeyboardLayoutInputSourceID$",
    ),
    "com.apple.SoftwareUpdate": (
        # Badge bookkeeping for whatever update is pending today.
        r"^AvailableUpdatesNotification",
    ),
    "com.apple.Spotlight": (r"^startTime$",),
}

# Casks with no app bundle to inspect (fonts, CLIs, pkg-only installers).
# Tracked so the run can report them instead of silently dropping them.
_NO_APP_NOTE = "no .app artifact"


def apple_path(flake_root: Path | None = None) -> Path:
    return (flake_root or _FLAKE_ROOT) / _APPLE_REL


def brew_path(flake_root: Path | None = None) -> Path:
    return (flake_root or _FLAKE_ROOT) / _BREW_REL


# --------------------------------------------------------------------------
# reading preferences
# --------------------------------------------------------------------------


def read_domain(domain: str) -> dict[str, Any]:
    """Read a preference domain via cfprefsd.

    `defaults export` is used rather than reading `~/Library/Preferences/*.plist`
    directly, so values cfprefsd has not flushed to disk yet are still seen. The
    result is parsed with `plistlib` rather than `plutil -convert json` because a
    single `<data>` or `<date>` value anywhere in a domain fails the whole JSON
    conversion, which silently drops every key in that domain.
    """
    proc = subprocess.run(
        ["defaults", "export", domain, "-"],
        capture_output=True,
        check=False,
    )
    if proc.returncode != 0 or not proc.stdout.strip():
        return {}
    try:
        data = plistlib.loads(proc.stdout)
    except Exception:  # noqa: BLE001 - a malformed domain is not worth failing on
        warn(f"{domain}: unreadable plist; skipping", stderr=True)
        return {}
    return data if isinstance(data, dict) else {}


# A preference the user set from a settings UI is a scalar or a small
# collection. Anything larger is a table macOS seeded itself — the VoiceOver
# language rotor (68 locales), Spaces display layouts, font size categories.
# Capping leaf count catches those generically instead of by name.
_MAX_VALUE_LEAVES = 24


def count_leaves(value: Any) -> int:
    if isinstance(value, dict):
        return sum(count_leaves(v) for v in value.values()) or 1
    if isinstance(value, list):
        return sum(count_leaves(v) for v in value) or 1
    return 1


_SECRET_DENIES = tuple(re.compile(p) for p in _SECRET_KEY_PATTERNS)


def _compiled_denies(domain: str) -> tuple[re.Pattern[str], ...]:
    patterns = _DENY_KEY_PATTERNS + _DENY_DOMAIN_KEYS.get(domain, ())
    return tuple(re.compile(p) for p in patterns)


def is_state_key(key: str, denies: tuple[re.Pattern[str], ...]) -> bool:
    return any(p.search(key) for p in denies)


def is_secret_key(key: str) -> bool:
    return any(p.search(key) for p in _SECRET_DENIES)


def coerce_scalar(value: Any) -> Any:
    """Normalise plist scalars to the types Home Manager declares.

    Home Manager types the well-known Apple keys (`types.bool`, `types.int`),
    and a plist that disagrees fails eval outright. Two mismatches occur in
    practice, both from how the value was originally written:

    * `defaults write <domain> <key> true` without `-bool` stores the *string*
      `"true"` — surfaced by `com.apple.desktopservices.DSDontWriteNetworkStores`.
    * UI-written sliders store `<real>` where the option is an int — surfaced by
      `com.apple.dock.tilesize` = 36.0.

    Integral reals become ints; fractional reals (mouse scaling and friends) are
    left alone. Only top-level scalars are coerced — inside lists and dicts the
    plist types are written back verbatim.
    """
    if isinstance(value, str) and value in ("true", "false"):
        return value == "true"
    if isinstance(value, float) and value.is_integer():
        return int(value)
    return value


def filter_domain(
    domain: str, prefs: dict[str, Any], *, filter_state: bool = True
) -> dict[str, Any]:
    """Drop secrets, state-looking keys, and values Nix cannot express."""
    denies = _compiled_denies(domain) if filter_state else ()
    out: dict[str, Any] = {}
    for key, value in prefs.items():
        name = str(key)
        if is_secret_key(name):
            continue
        if filter_state and is_state_key(name, denies):
            continue
        if filter_state and count_leaves(value) > _MAX_VALUE_LEAVES:
            continue
        # An empty list or dict declares nothing — it is a container the app
        # created and never filled (`DisabledUTTypes`, the pending-toolbar-item
        # queues). Keys whose emptiness *is* the intent are denied by name.
        if filter_state and isinstance(value, (list, dict)) and not value:
            continue
        if to_nix_value(value) is None:
            continue
        out[name] = coerce_scalar(value)
    return out


def sandboxed_prefs_exist(domain: str) -> bool:
    """True when a domain keeps its prefs inside an app sandbox container.

    `defaults write` — and therefore `targets.darwin.defaults` — cannot reach a
    container, so these domains are reported and skipped instead of captured
    into a module that would never take effect.
    """
    container = (
        Path.home()
        / "Library/Containers"
        / domain
        / "Data/Library/Preferences"
        / f"{domain}.plist"
    )
    return container.is_file()


# --------------------------------------------------------------------------
# homebrew cask discovery
# --------------------------------------------------------------------------


@dataclass(frozen=True)
class CaskApp:
    token: str
    domain: str


def _brew(*args: str) -> str | None:
    try:
        proc = subprocess.run(
            ["brew", *args], capture_output=True, text=True, check=False
        )
    except FileNotFoundError:
        return None
    if proc.returncode != 0:
        return None
    return proc.stdout


def installed_casks() -> list[str]:
    out = _brew("list", "--cask")
    return out.split() if out is not None else []


def cask_bundle_ids(token: str) -> tuple[list[str], str | None]:
    """Bundle identifiers for an installed cask, plus a skip reason if none.

    `brew list --cask <token>` is used instead of `brew info --json` because it
    works offline and never loads the cask definition: `brew info` refuses casks
    from untrusted third-party taps, and one such cask makes a batched call fail
    for every other cask too.
    """
    out = _brew("list", "--cask", token)
    if out is None:
        return [], "brew list failed"
    apps = [
        line
        for line in out.splitlines()
        if line.endswith(".app") and "/.metadata/" not in line
    ]
    if not apps:
        return [], _NO_APP_NOTE
    ids: list[str] = []
    for app in apps:
        try:
            data = plistlib.loads((Path(app) / "Contents/Info.plist").read_bytes())
        except (OSError, plistlib.InvalidFileException):
            # Dangling Caskroom symlink: cask still registered, app bundle gone.
            continue
        bundle_id = data.get("CFBundleIdentifier")
        if isinstance(bundle_id, str) and bundle_id:
            ids.append(bundle_id)
    if not ids:
        return [], "app bundle missing"
    return ids, None


def discover_cask_apps() -> tuple[list[CaskApp], dict[str, str]]:
    apps: list[CaskApp] = []
    skipped: dict[str, str] = {}
    for token in installed_casks():
        ids, reason = cask_bundle_ids(token)
        if reason is not None:
            skipped[token] = reason
            continue
        apps.extend(CaskApp(token=token, domain=bundle_id) for bundle_id in ids)
    return apps, skipped


# --------------------------------------------------------------------------
# hand-owned domains
# --------------------------------------------------------------------------

_HAND_OWNED_RE = re.compile(
    r"""targets\.darwin\.defaults\.(?:"(?P<quoted>[^"]+)"|(?P<bare>[A-Za-z_][\w'-]*))"""
)


# Domains a Nix module writes *programmatically*, so `hand_owned_domains` can't
# see them. Capturing one would declare it twice (Home Manager conflict) and
# freeze a snapshot of generated content — e.g. Zen's whole policy/
# ExtensionSettings blob, which the zen-browser HM module derives from
# modules/profiles/apps/browsers/zen/policies.nix.
_MODULE_OWNED_DOMAINS: frozenset[str] = frozenset(
    {
        "app.zen-browser.zen",
    }
)


def hand_owned_domains(flake_root: Path | None = None) -> set[str]:
    """Domains configured by hand somewhere in the flake.

    Only the `targets.darwin.defaults."domain"` form is detected; a domain
    nested inside a `targets.darwin.defaults = { ... }` block is not, so keep
    hand-owned modules in the dotted form to stay visible here.
    """
    root = flake_root or _FLAKE_ROOT
    generated = {apple_path(root).resolve(), brew_path(root).resolve()}
    found: set[str] = set()
    for path in root.rglob("*.nix"):
        if path.resolve() in generated:
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError):
            continue
        for match in _HAND_OWNED_RE.finditer(text):
            found.add(match.group("quoted") or match.group("bare"))
    return found | _MODULE_OWNED_DOMAINS


# --------------------------------------------------------------------------
# nix rendering
# --------------------------------------------------------------------------


def nix_escape(value: str) -> str:
    return (
        value.replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("${", "\\${")
        .replace("\n", "\\n")
        .replace("\t", "\\t")
    )


# Nix keywords are not usable as bare attribute names, and preference keys do
# collide with them in practice (Messages ships a `with` key).
_NIX_KEYWORDS = frozenset(
    {
        "assert",
        "else",
        "if",
        "in",
        "inherit",
        "let",
        "or",
        "rec",
        "then",
        "with",
    }
)


def nix_attr_key(key: str) -> str:
    if key not in _NIX_KEYWORDS and re.fullmatch(r"[A-Za-z_][A-Za-z0-9_'-]*", key):
        return key
    return f'"{nix_escape(key)}"'


def to_nix_value(value: Any, indent: int = 2) -> str | None:
    """Convert a plist value to Nix. Returns None for anything unrepresentable.

    `bytes` (plist `<data>`) and `datetime` (`<date>`) are deliberately
    unsupported: neither round-trips through `defaults write` as a scalar, and
    both only ever show up in opaque state we would not want to declare anyway.
    Containers are all-or-nothing — dropping an element or an attribute would
    silently rewrite the setting rather than skip it.
    """
    pad = " " * indent
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return str(value)
    if isinstance(value, str):
        return f'"{nix_escape(value)}"'
    if isinstance(value, list):
        if not value:
            return "[]"
        items: list[str] = []
        for item in value:
            rendered = to_nix_value(item, indent + 2)
            if rendered is None:
                return None
            items.append(f"{pad}  {rendered}")
        return "[\n" + "\n".join(items) + f"\n{pad}]"
    if isinstance(value, dict):
        pairs: list[tuple[str, str]] = []
        for nested_key in sorted(value, key=str):
            rendered = to_nix_value(value[nested_key], indent + 2)
            if rendered is None:
                return None
            pairs.append((nix_attr_key(str(nested_key)), rendered))
        if not pairs:
            return "{ }"
        lines = ["{"]
        lines.extend(f"{pad}  {k} = {v};" for k, v in pairs)
        lines.append(f"{pad}}}")
        return "\n".join(lines)
    return None


def render_module(domains: dict[str, dict[str, Any]], *, note: str) -> str:
    lines = [
        f"# GENERATED by {_SYNC_TOOL}. DO NOT EDIT.",
        f"# {note}",
        f"# Sync: just {_SYNC_TOOL}-sync   Check: just {_SYNC_TOOL}-check",
        "{ ... }:",
        "{",
        "  targets.darwin.defaults = {",
    ]
    for domain in sorted(domains):
        prefs = domains[domain]
        if not prefs:
            continue
        lines.append(f"    {nix_attr_key(domain)} = {{")
        for key in sorted(prefs, key=str):
            rendered = to_nix_value(prefs[key], indent=6)
            if rendered is None:
                continue
            lines.append(f"      {nix_attr_key(str(key))} = {rendered};")
        lines.append("    };")
    lines.extend(["  };", "}", ""])
    return "\n".join(lines)


def nix_fmt(content: str) -> str:
    if not content:
        return content
    proc = subprocess.run(
        ["nixfmt", "-"],
        input=content,
        text=True,
        capture_output=True,
        check=False,
    )
    if proc.returncode != 0:
        msg = proc.stderr.strip() or f"exit {proc.returncode}"
        raise RuntimeError(f"nixfmt failed: {msg}")
    return proc.stdout


def unified_diff(name: str, actual: str, expected: str) -> list[str]:
    if actual == expected:
        return []
    return list(
        difflib.unified_diff(
            actual.splitlines(keepends=True),
            expected.splitlines(keepends=True),
            fromfile=name,
            tofile=f"{name} (live)",
        )
    )


# --------------------------------------------------------------------------
# collection
# --------------------------------------------------------------------------


def collect(
    domains: list[str],
    *,
    skip: set[str],
    filter_state: bool,
    label: str,
    quiet: bool,
) -> dict[str, dict[str, Any]]:
    out: dict[str, dict[str, Any]] = {}
    for domain in domains:
        if domain in skip:
            if not quiet:
                info(f"{label}: {domain} is hand-owned in the flake; skipping")
            continue
        prefs = read_domain(domain)
        if not prefs:
            if sandboxed_prefs_exist(domain) and not quiet:
                warn(
                    f"{label}: {domain} keeps prefs in its sandbox container; "
                    "targets.darwin.defaults cannot write there",
                    stderr=True,
                )
            continue
        prefs = filter_domain(domain, prefs, filter_state=filter_state)
        if prefs:
            out[domain] = prefs
    return out


@dataclass
class Target:
    rel: Path
    domains: dict[str, dict[str, Any]]
    note: str


def build_targets(
    *,
    only_domains: list[str] | None,
    include_apple: bool,
    include_brew: bool,
    filter_state: bool,
    quiet: bool,
    flake_root: Path,
) -> list[Target]:
    hand_owned = hand_owned_domains(flake_root)
    targets: list[Target] = []

    if include_apple:
        wanted = list(APPLE_DOMAINS)
        if only_domains is not None:
            wanted = [d for d in wanted if d in only_domains]
        targets.append(
            Target(
                rel=_APPLE_REL,
                domains=collect(
                    wanted,
                    skip=hand_owned,
                    filter_state=filter_state,
                    label="apple",
                    quiet=quiet,
                ),
                note="Apple/System Settings domains (allowlist in darwin_defaults.py).",
            )
        )

    if include_brew:
        apps, skipped = discover_cask_apps()
        if not quiet:
            for token, reason in sorted(skipped.items()):
                if reason != _NO_APP_NOTE:
                    warn(f"cask {token}: {reason}", stderr=True)
        wanted = sorted({a.domain for a in apps})
        if only_domains is not None:
            wanted = [d for d in wanted if d in only_domains]
        # The Apple module already owns its allowlist; declaring a domain in both
        # generated files would be a Home Manager conflict.
        targets.append(
            Target(
                rel=_BREW_REL,
                domains=collect(
                    wanted,
                    skip=hand_owned | set(APPLE_DOMAINS),
                    filter_state=filter_state,
                    label="brew",
                    quiet=quiet,
                ),
                note="Homebrew cask app domains, discovered from the live cask list.",
            )
        )

    return targets


def sync_defaults(
    *,
    check: bool,
    quiet: bool,
    only_domains: list[str] | None,
    include_apple: bool,
    include_brew: bool,
    filter_state: bool,
    flake_root: Path | None = None,
) -> int:
    root = flake_root or _FLAKE_ROOT
    targets = build_targets(
        only_domains=only_domains,
        include_apple=include_apple,
        include_brew=include_brew,
        filter_state=filter_state,
        quiet=quiet,
        flake_root=root,
    )

    stale: list[Path] = []
    for target in targets:
        path = root / target.rel
        expected = nix_fmt(render_module(target.domains, note=target.note))
        actual_raw = path.read_text(encoding="utf-8") if path.is_file() else ""
        actual = nix_fmt(actual_raw) if actual_raw.strip() else ""
        if actual == expected:
            continue
        stale.append(target.rel)
        if not quiet:
            for line in unified_diff(str(target.rel), actual, expected):
                print(line, end="", file=sys.stderr)
        if not check:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(expected, encoding="utf-8")
            if not quiet:
                info(f"Wrote {target.rel}", stderr=True)
                info(
                    f"  domains: {', '.join(sorted(target.domains)) or '(none)'}",
                    stderr=True,
                )

    if check:
        if stale:
            bad(
                "Flake Darwin defaults are stale: " + ", ".join(str(p) for p in stale),
                stderr=True,
            )
            return 1
        if not quiet:
            info("Flake Darwin defaults match the live system.", stderr=True)
        return 0

    if not stale and not quiet:
        info("Already up to date.", stderr=True)
    return 0


def require_darwin() -> int | None:
    if sys.platform == "darwin":
        return None
    bad("darwin-defaults only runs on macOS.", stderr=True)
    return 1


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(
        prog=_SYNC_TOOL,
        description="Check/sync macOS defaults (Apple panes + Homebrew casks) into the flake",
    )
    ap.add_argument(
        "--check",
        action="store_true",
        help="Compare only; do not write the generated modules",
    )
    ap.add_argument(
        "--quiet", "-q", action="store_true", help="Suppress non-error output"
    )
    ap.add_argument(
        "--domain",
        action="append",
        dest="domains",
        metavar="DOMAIN",
        help="Limit to these domains (repeatable)",
    )
    ap.add_argument(
        "--apple-only",
        action="store_true",
        help="Only refresh the Apple/System Settings module",
    )
    ap.add_argument(
        "--brew-only",
        action="store_true",
        help="Only refresh the Homebrew cask module",
    )
    ap.add_argument(
        "--list-domains",
        action="store_true",
        help="Print the Apple allowlist, discovered cask domains, and hand-owned domains",
    )
    ap.add_argument(
        "--include-state-keys",
        action="store_true",
        help="Do not filter volatile/state-looking keys (debugging aid)",
    )
    ap.add_argument(
        "--flake-root",
        type=Path,
        default=None,
        help="Override flake root (default: $FLAKE / walk-up)",
    )
    args = ap.parse_args(argv)

    blocked = require_darwin()
    if blocked is not None:
        return blocked

    if args.list_domains:
        print("# Apple allowlist")
        for domain in APPLE_DOMAINS:
            print(domain)
        print("\n# Homebrew cask domains (discovered)")
        apps, skipped = discover_cask_apps()
        for app in sorted(apps, key=lambda a: (a.token, a.domain)):
            print(f"{app.domain}  # {app.token}")
        for token, reason in sorted(skipped.items()):
            print(f"# {token}: {reason}")
        print("\n# Hand-owned in the flake (never generated)")
        for domain in sorted(hand_owned_domains(args.flake_root)):
            print(domain)
        return 0

    if args.apple_only and args.brew_only:
        bad("--apple-only and --brew-only are mutually exclusive", stderr=True)
        return 2

    try:
        return sync_defaults(
            check=args.check,
            quiet=args.quiet,
            only_domains=args.domains,
            include_apple=not args.brew_only,
            include_brew=not args.apple_only,
            filter_state=not args.include_state_keys,
            flake_root=args.flake_root,
        )
    except RuntimeError as exc:
        bad(str(exc), stderr=True)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
