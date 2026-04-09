"""Check desktop config symlinks (DMS, niri, quickshell) against the flake."""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

from flake_scripts.lib import common as C


def _single_symlink_audit(path: Path) -> None:
    if path.is_symlink():
        target = path.resolve()
        line = f"{path} → {target}"
        if target.is_file():
            C.ok(line)
        else:
            C.bad(f"{line} (target missing)")
    elif path.is_file():
        C.bad(f"{path} is a regular file (not a symlink)")
    else:
        C.warn(f"{path} does not exist")


def cmd_all(flake: Path) -> int:
    ch = C.xdg_config_home()
    dms, niri = ch / "DankMaterialShell", ch / "niri"
    qs = ch / "quickshell" / "config.kdl"

    C.rule("DMS config symlinks")
    C.print_dir_symlink_audit(dms)

    C.rule("Niri config symlinks")
    C.print_dir_symlink_audit(niri)

    C.rule("Quickshell config")
    _single_symlink_audit(qs)

    C.rule("Summary")
    C.dim(f"Expected: {dms}/* → {flake}/home/nixos/desktop/dms/config/*")
    C.dim(f"Expected: {niri}/* → {flake}/home/nixos/desktop/niri/*")
    C.dim(f"Expected: {qs} → {flake}/home/nixos/desktop/dms/config/config.kdl")
    C.info(f"Edit under {flake}/home/nixos/desktop/dms/config/ and confirm ~/.config/DankMaterialShell/ sees it.")
    return 0


def cmd_dms_settings(flake: Path) -> int:
    dms_file = C.xdg_config_home() / "DankMaterialShell" / "settings.json"
    dms_config_dir = (flake / "home/nixos/desktop/dms/config").resolve()

    C.rule("DMS settings.json")
    if not dms_file.exists():
        C.bad(f"{dms_file} does not exist — rebuild may be required")
        return 1

    if dms_file.is_symlink():
        C.ok(f"{dms_file} is a symlink")
        target = dms_file.resolve()
        C.dim(f"  → {target}")
        if not C.is_path_under(target, dms_config_dir):
            C.bad("Resolves outside flake DMS config tree")
            C.dim(f"  expected under {dms_config_dir}")
            info_fix()
            return 1
        C.ok(f"Under {dms_config_dir}")
    elif dms_file.is_file():
        C.bad(f"{dms_file} is a regular file (not a symlink)")
        C.dim("DMS may be writing outside the flake.")
        console_fix_regular_file(dms_file)
        return 1
    else:
        C.bad(f"{dms_file} is not a file or symlink")
        return 1

    C.rule("Write access")
    flake_target = dms_file.resolve()
    if not os.access(dms_file, os.W_OK):
        C.bad("Not writable")
        return 1
    C.ok("Writable")
    try:
        if dms_file.stat().st_mtime != flake_target.stat().st_mtime:
            C.warn("mtime differs (recent change or new symlink is OK)")
            C.dim(f"  config: {C.format_mtime(dms_file)}")
            C.dim(f"  flake:  {C.format_mtime(flake_target)}")
    except OSError:
        pass

    C.rule("OK")
    C.ok(f"GUI edits should land in [bold]{flake_target}[/]")
    return 0


def info_fix() -> None:
    C.dim("  just switch-fast")


def console_fix_regular_file(dms_file: Path) -> None:
    C.dim(f"  cp {dms_file} {dms_file}.backup")
    C.dim("  just switch-fast")


def main(args: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(
        description="Verify DMS / niri / quickshell config symlinks against the flake.",
    )
    ap.add_argument(
        "--flake",
        type=Path,
        metavar="DIR",
        help="Flake root (default: $FLAKE, upward flake.nix, else ~/.dotfiles/flake)",
    )
    sub = ap.add_subparsers(dest="command", metavar="COMMAND")
    sub.add_parser("all", help="DMS, niri, quickshell report (non-fatal)")
    sub.add_parser("dms-settings", help="Strict DMS settings.json → flake (exit 1 on failure)")
    ns = ap.parse_args(args)
    flake = C.resolve_flake_root(ns.flake)
    cmd = ns.command or "all"
    if cmd == "all":
        return cmd_all(flake)
    if cmd == "dms-settings":
        return cmd_dms_settings(flake)
    ap.print_help()
    return 2


if __name__ == "__main__":
    sys.exit(main())
