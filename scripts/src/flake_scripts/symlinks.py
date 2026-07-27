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


def _flake_noctalia_config(flake: Path, config_name: str = "config.toml") -> Path:
    return (flake / "modules/profiles/desktop/noctalia/config" / config_name).resolve()


def _audit_noctalia_config(
    config_file: Path, flake_config: Path, *, strict: bool
) -> int:
    if not config_file.exists():
        C.bad(f"{config_file} does not exist — rebuild may be required")
        return 1

    if not flake_config.is_file():
        C.bad(f"Flake config missing: {flake_config}")
        return 1

    expected = flake_config.read_text()
    issues = 0

    if config_file.is_symlink():
        target = config_file.resolve()
        C.dim(f"{config_file} → {target}")
        if C.is_path_under(target, flake_config.parent):
            C.ok("Legacy flake symlink")
        else:
            issues += 1
            C.bad("Symlink resolves outside flake noctalia config tree")
            return 1
        if target.read_text() != expected:
            issues += 1
            msg = "Deployed config differs from flake — run just switch-fast"
            (C.bad if strict else C.warn)(msg)
        else:
            C.ok("Matches flake config.toml")
        return issues

    if config_file.is_file():
        C.ok("Home Manager managed (regular file)")
        if config_file.read_text() == expected:
            C.ok("Content matches flake config.toml")
        else:
            issues += 1
            msg = "Deployed config differs from flake — run just switch-fast"
            (C.bad if strict else C.warn)(msg)
        return issues

    C.bad(f"{config_file} is not a file or symlink")
    return 1


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

    C.rule("Noctalia config.toml")
    issues += _audit_noctalia_config(
        noctalia / "config.toml",
        _flake_noctalia_config(flake),
        strict=False,
    )

    C.rule("Niri config symlinks")
    issues += C.print_dir_symlink_audit(niri)

    C.rule("Quickshell config")
    issues += _single_symlink_audit(qs)

    C.rule("Summary")
    C.dim(f"Expected: {dms}/* → {flake}/modules/profiles/desktop/dms/config/*")
    C.dim(
        f"Expected: {noctalia}/config.toml — HM copy of "
        f"{flake}/modules/profiles/desktop/noctalia/config/config.toml "
        f"(just switch-fast after edits)"
    )
    C.dim(f"Expected: {niri}/* → {flake}/modules/profiles/desktop/niri/*")
    C.dim(f"Expected: {qs} → {flake}/modules/profiles/desktop/dms/config/config.kdl")
    C.info(
        f"Edit DMS/niri under {flake}/modules/profiles/desktop/; "
        f"Noctalia TOML needs just switch-fast after edits."
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


def cmd_noctalia_config(flake: Path) -> int:
    noctalia_file = C.xdg_config_home() / "noctalia" / "config.toml"
    C.rule("Noctalia config.toml")
    issues = _audit_noctalia_config(
        noctalia_file,
        _flake_noctalia_config(flake),
        strict=True,
    )
    if issues:
        return issues

    C.rule("OK")
    C.ok(
        "Hand-edits: flake config.toml (then just switch-fast); GUI overrides: "
        "~/.local/state/noctalia/settings.toml"
    )
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
        "noctalia-config",
        help="Strict Noctalia config.toml matches flake (exit 1 on failure)",
    )
    ns = ap.parse_args(args)
    flake = C.resolve_flake_root(ns.flake)
    cmd = ns.command or "all"
    if cmd == "all":
        return cmd_all(flake)
    if cmd == "dms-settings":
        return cmd_dms_settings(flake)
    if cmd == "noctalia-config":
        return cmd_noctalia_config(flake)
    ap.print_help()
    return 2


if __name__ == "__main__":
    sys.exit(main())
