"""Check desktop config symlinks (DMS, Noctalia, niri, quickshell) against the flake."""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

from flake_scripts.lib import common as C


def _single_symlink_audit(path: Path) -> int:
    issues = 0
    if path.is_symlink():
        raw = os.readlink(path)
        target = path.resolve()
        line = f"{path} → {target}"
        if C.symlink_has_store_hop(path):
            issues += 1
            C.warn(f"{line} (store hop via {raw}; run just switch-fast)")
        elif target.is_file():
            C.ok(line)
        else:
            issues += 1
            C.bad(f"{line} (target missing)")
    elif path.is_file():
        issues += 1
        C.bad(f"{path} is a regular file (not a symlink)")
    else:
        C.warn(f"{path} does not exist")
    return issues


def _noctalia_config_dir(flake: Path) -> Path:
    return (flake / "modules/profiles/desktop/noctalia/config").resolve()


def _noctalia_settings_file() -> Path:
    # The state-dir settings.toml overrides ~/.config/noctalia/config.toml, so
    # this is the file that decides what noctalia actually does — and the one the
    # GUI writes. config.toml is HM-generated into the store (Stylix merges into
    # it) and is deliberately not audited against the flake.
    return C.xdg_state_home() / "noctalia" / "settings.toml"


def _audit_config_file(label: str, config_file: Path, config_dir: Path) -> int:
    C.rule(label)
    if not config_file.exists():
        C.bad(f"{config_file} does not exist — rebuild may be required")
        return 1

    if config_file.is_symlink():
        issues = 0
        raw = os.readlink(config_file)
        target = config_file.resolve()
        if C.symlink_has_store_hop(config_file):
            issues += 1
            C.warn(f"Store hop: {raw} → {target}")
            C.dim("  just switch-fast repoints via directFlakeSymlinks")
        else:
            C.ok(f"{config_file} is a symlink")
            C.dim(f"  → {target}")
        if not C.is_path_under(target, config_dir):
            C.bad("Resolves outside flake config tree")
            C.dim(f"  expected under {config_dir}")
            info_fix()
            return 1
        C.ok(f"Under {config_dir}")
        return issues

    if config_file.is_file():
        C.bad(f"{config_file} is a regular file (not a symlink)")
        console_fix_regular_file(config_file)
        return 1

    C.bad(f"{config_file} is not a file or symlink")
    return 1


def cmd_all(flake: Path) -> int:
    ch = C.xdg_config_home()
    dms, noctalia, niri = ch / "DankMaterialShell", ch / "noctalia", ch / "niri"
    qs = ch / "quickshell" / "config.kdl"

    issues = 0

    C.rule("DMS config symlinks")
    issues += C.print_dir_symlink_audit(dms)

    issues += _audit_config_file(
        "Noctalia settings.toml",
        _noctalia_settings_file(),
        _noctalia_config_dir(flake),
    )

    C.rule("Niri config symlinks")
    issues += C.print_dir_symlink_audit(niri)

    C.rule("Quickshell config")
    issues += _single_symlink_audit(qs)

    C.rule("Summary")
    C.dim(f"Expected: {dms}/* → {flake}/modules/profiles/desktop/dms/config/*")
    C.dim(
        f"Expected: {_noctalia_settings_file()} → "
        f"{flake}/modules/profiles/desktop/noctalia/config/settings.toml "
        f"({noctalia}/config.toml is HM-generated with Stylix merged in, and is "
        f"overridden by that settings.toml)"
    )
    C.dim(f"Expected: {niri}/* → {flake}/modules/profiles/desktop/niri/*")
    C.dim(f"Expected: {qs} → {flake}/modules/profiles/desktop/dms/config/config.kdl")
    C.info(
        f"Edit DMS/niri/Noctalia under {flake}/modules/profiles/desktop/. "
        f"Noctalia's settings.toml is live-symlinked, so GUI changes land in the "
        f"checkout; only the config.toml base layer needs just switch-fast."
    )
    if issues:
        C.warn(
            f"{issues} symlink issue(s) — run just switch-fast to repoint store hops"
        )
    return 0


def cmd_dms_settings(flake: Path) -> int:
    dms_file = C.xdg_config_home() / "DankMaterialShell" / "settings.json"
    dms_config_dir = (flake / "modules/profiles/desktop/dms/config").resolve()
    issues = _audit_config_file("DMS settings.json", dms_file, dms_config_dir)
    if issues:
        return issues

    C.rule("Write access")
    flake_target = dms_file.resolve()
    if not os.access(dms_file, os.W_OK):
        C.bad("Not writable")
        return 1
    C.ok("Writable")

    C.rule("OK")
    C.ok(f"GUI edits should land in [bold]{flake_target}[/]")
    return 0


def cmd_noctalia_settings(flake: Path) -> int:
    settings_file = _noctalia_settings_file()
    issues = _audit_config_file(
        "Noctalia settings.toml", settings_file, _noctalia_config_dir(flake)
    )
    if issues:
        return issues

    C.rule("Write access")
    flake_target = settings_file.resolve()
    if not os.access(settings_file, os.W_OK):
        C.bad("Not writable")
        return 1
    C.ok("Writable")

    C.rule("OK")
    C.ok(f"GUI edits should land in [bold]{flake_target}[/]")
    return 0


def info_fix() -> None:
    C.dim("  just switch-fast")


def console_fix_regular_file(config_file: Path) -> None:
    C.dim(f"  cp {config_file} {config_file}.backup")
    C.dim("  just switch-fast")


def main(args: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(
        description="Verify DMS / Noctalia / niri / quickshell config symlinks against the flake.",
    )
    ap.add_argument(
        "--flake",
        type=Path,
        metavar="DIR",
        help="Flake root (default: $FLAKE, upward flake.nix, else ~/.dotfiles/flake)",
    )
    sub = ap.add_subparsers(dest="command", metavar="COMMAND")
    sub.add_parser("all", help="DMS, Noctalia, niri, quickshell report (non-fatal)")
    sub.add_parser(
        "dms-settings", help="Strict DMS settings.json → flake (exit 1 on failure)"
    )
    sub.add_parser(
        "noctalia-settings",
        help="Strict Noctalia settings.toml → flake (exit 1 on failure)",
    )
    ns = ap.parse_args(args)
    flake = C.resolve_flake_root(ns.flake)
    cmd = ns.command or "all"
    if cmd == "all":
        return cmd_all(flake)
    if cmd == "dms-settings":
        return cmd_dms_settings(flake)
    if cmd == "noctalia-settings":
        return cmd_noctalia_settings(flake)
    ap.print_help()
    return 2


if __name__ == "__main__":
    sys.exit(main())
