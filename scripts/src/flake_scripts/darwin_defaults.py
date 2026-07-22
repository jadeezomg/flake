#!/usr/bin/env python3
"""Capture allowlisted macOS defaults into the flake (check + sync).

Writes `modules/profiles/minimal/darwin/defaults.generated.nix` for Home Manager
`targets.darwin.defaults`. Brew-cask prefs stay hand-owned under work/darwin.
"""

from __future__ import annotations

import argparse
import difflib
import json
import re
import subprocess
import sys
from pathlib import Path
from typing import Any

from flake_scripts.lib.common import bad, info, resolve_flake_root, warn

_FLAKE_ROOT = resolve_flake_root(anchor=Path(__file__))
_SYNC_TOOL = "darwin-defaults"
_GENERATED_REL = Path("modules/profiles/minimal/darwin/defaults.generated.nix")

# Core Apple UI domains — expand deliberately; do not dump everything.
ALLOWLIST: tuple[str, ...] = (
    "NSGlobalDomain",
    "com.apple.dock",
    "com.apple.finder",
    "com.apple.Safari",
    "com.apple.screencapture",
    "com.apple.trackpad",
    "com.apple.AppleMultitouchTrackpad",
    "com.apple.driver.AppleBluetoothMultitouch.trackpad",
    "com.apple.controlcenter",
    "com.apple.WindowManager",
)

_SYSTEM_KEY_PATTERNS = (
    r"^SU",
    r"^NSStatusItem",
    r"LastCheck",
    r"LastUpdate",
    r"LastSync",
    r"Cache",
    r"CacheDate",
    r"InstallId",
    r"SessionId",
    r"UserId",
    r"Migrated",
    r"Migration",
    r"Version",
    r"PreferencesVersion",
    r"HasLaunched",
    r"HasRunBefore",
    r"TerminatedWith",
    r"MSAppCenter",
    r"DataSeparated",
    r"ViewSettings$",
    r"WindowLocation",
    r"ProgressWindow",
)


def generated_path(flake_root: Path | None = None) -> Path:
    root = flake_root or _FLAKE_ROOT
    return root / _GENERATED_REL


def domain_plist_path(domain: str) -> Path:
    home = Path.home()
    if domain == "NSGlobalDomain":
        return home / "Library/Preferences/.GlobalPreferences.plist"
    return home / "Library/Preferences" / f"{domain}.plist"


def is_system_key(key: str) -> bool:
    return any(re.search(pattern, key) for pattern in _SYSTEM_KEY_PATTERNS)


def nix_escape(value: str) -> str:
    return (
        value.replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("\n", "\\n")
        .replace("\t", "\\t")
    )


def nix_attr_key(key: str) -> str:
    if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_'-]*", key):
        return key
    return f'"{nix_escape(key)}"'


def to_nix_value(value: Any, indent: int = 2) -> str | None:
    """Convert JSON-ish plist values to Nix. Returns None for unsupported types."""
    pad = " " * indent
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int) and not isinstance(value, bool):
        return str(value)
    if isinstance(value, float):
        return str(value)
    if isinstance(value, str):
        return f'"{nix_escape(value)}"'
    if value is None:
        return "null"
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
        if not value:
            return "{ }"
        lines: list[str] = ["{"]
        for nested_key in sorted(value):
            rendered = to_nix_value(value[nested_key], indent + 2)
            if rendered is None:
                continue
            lines.append(f"{pad}  {nix_attr_key(str(nested_key))} = {rendered};")
        lines.append(f"{pad}}}")
        return "\n".join(lines)
    return None


def read_domain(domain: str, *, filter_system: bool = True) -> dict[str, Any]:
    plist = domain_plist_path(domain)
    prefs: dict[str, Any] = {}
    if plist.is_file():
        proc = subprocess.run(
            ["plutil", "-convert", "json", "-o", "-", str(plist)],
            capture_output=True,
            text=True,
            check=False,
        )
        if proc.returncode == 0 and proc.stdout.strip():
            data = json.loads(proc.stdout)
            if isinstance(data, dict):
                prefs = data
    if not prefs:
        proc = subprocess.run(
            ["defaults", "read", domain],
            capture_output=True,
            text=True,
            check=False,
        )
        if proc.returncode != 0 or not proc.stdout.strip():
            return {}
        warn(f"{domain}: plist missing/unreadable; skipping", stderr=True)
        return {}
    if filter_system:
        prefs = {k: v for k, v in prefs.items() if not is_system_key(str(k))}
    return prefs


def collect_domains(
    domains: tuple[str, ...] | list[str],
    *,
    filter_system: bool = True,
) -> dict[str, dict[str, Any]]:
    out: dict[str, dict[str, Any]] = {}
    for domain in domains:
        prefs = read_domain(domain, filter_system=filter_system)
        if prefs:
            out[domain] = prefs
    return out


def render_module(domains: dict[str, dict[str, Any]]) -> str:
    lines = [
        f"# GENERATED by {_SYNC_TOOL}. DO NOT EDIT.",
        f"# Sync: just {_SYNC_TOOL}-sync",
        f"# Check: just {_SYNC_TOOL}-check",
        "{ ... }: {",
        "  targets.darwin.defaults = {",
    ]
    for domain in sorted(domains):
        prefs = domains[domain]
        lines.append(f"    {nix_attr_key(domain)} = {{")
        for key in sorted(prefs):
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


def require_darwin() -> int | None:
    if sys.platform == "darwin":
        return None
    bad("darwin-defaults only runs on macOS.", stderr=True)
    return 1


def sync_defaults(
    *,
    check: bool,
    quiet: bool,
    domains: tuple[str, ...] | list[str],
    filter_system: bool,
    flake_root: Path | None = None,
) -> int:
    root = flake_root or _FLAKE_ROOT
    path = generated_path(root)
    live = collect_domains(domains, filter_system=filter_system)
    expected = nix_fmt(render_module(live))
    actual_raw = path.read_text(encoding="utf-8") if path.is_file() else ""
    actual = nix_fmt(actual_raw) if actual_raw else ""
    matches = actual == expected
    if not matches and not quiet:
        for line in unified_diff(str(_GENERATED_REL), actual, expected):
            print(line, end="", file=sys.stderr)
    if check:
        if matches:
            if not quiet:
                info("Flake Darwin defaults match the live allowlist.", stderr=True)
            return 0
        bad("Flake Darwin defaults do not match the live allowlist.", stderr=True)
        return 1
    if matches:
        if not quiet:
            info("Already up to date.", stderr=True)
        return 0
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(expected, encoding="utf-8")
    if not quiet:
        info(f"Wrote {path}", stderr=True)
        info(f"Domains: {', '.join(sorted(live)) or '(none)'}", stderr=True)
        info("Done.", stderr=True)
    return 0


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(
        prog=_SYNC_TOOL,
        description="Check/sync allowlisted macOS defaults into the flake",
    )
    ap.add_argument(
        "--check",
        action="store_true",
        help="Compare only; do not write defaults.generated.nix",
    )
    ap.add_argument(
        "--quiet",
        "-q",
        action="store_true",
        help="Suppress non-error output",
    )
    ap.add_argument(
        "--domain",
        action="append",
        dest="domains",
        metavar="DOMAIN",
        help="Limit to one allowlisted domain (repeatable)",
    )
    ap.add_argument(
        "--list-allowlist",
        action="store_true",
        help="Print the default domain allowlist and exit",
    )
    ap.add_argument(
        "--include-system-keys",
        action="store_true",
        help="Do not filter volatile/system-looking keys",
    )
    ap.add_argument(
        "--flake-root",
        type=Path,
        default=None,
        help="Override flake root (default: $FLAKE / walk-up)",
    )
    args = ap.parse_args(argv)

    if args.list_allowlist:
        for domain in ALLOWLIST:
            print(domain)
        return 0

    blocked = require_darwin()
    if blocked is not None:
        return blocked

    if args.domains:
        unknown = [d for d in args.domains if d not in ALLOWLIST]
        if unknown:
            bad(
                "domain(s) not in allowlist: "
                + ", ".join(unknown)
                + " (use --list-allowlist)",
                stderr=True,
            )
            return 2
        selected = args.domains
    else:
        selected = list(ALLOWLIST)

    try:
        return sync_defaults(
            check=args.check,
            quiet=args.quiet,
            domains=selected,
            filter_system=not args.include_system_keys,
            flake_root=args.flake_root,
        )
    except RuntimeError as exc:
        bad(str(exc), stderr=True)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
