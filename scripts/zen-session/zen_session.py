#!/usr/bin/env python3
"""Single entry point for Zen session scripts. Override profile with --profile / -p."""

import os
import sys

_SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
_SRC_DIR = os.path.join(_SCRIPT_DIR, "src")
if _SRC_DIR not in sys.path:
    sys.path.insert(0, _SRC_DIR)


def main():
    import argparse

    ap = argparse.ArgumentParser(
        prog="zen_session.py",
        description="Zen session tools (extract, sync, compare, dump, check-spaces)",
    )
    ap.add_argument(
        "--profile",
        "-p",
        metavar="DIR",
        help="Zen browser profile dir (default: ZEN_PROFILE_ROOT; macOS: ~/Library/Application Support/zen/Profiles/default; else $XDG_CONFIG_HOME/zen/default; on NixOS, scans ~/.config/zen/* if default has no zen-sessions.jsonlz4)",
    )
    sub = ap.add_subparsers(dest="command", required=True)

    p = sub.add_parser("extract", help="Extract pinned tabs per workspace")
    p.add_argument("--nix", action="store_true", help="Print Nix snippet")
    p.add_argument(
        "--zen-sessions-file",
        metavar="PATH",
        help="Use a specific zen-sessions*.jsonlz4 file (e.g. from zen-sessions-backup/).",
    )
    p.add_argument(
        "--window-session-file",
        metavar="PATH",
        help="Use a specific sessionstore-backups/recovery*.jsonlz4 file for windows/tabs.",
    )
    p.add_argument(
        "--dump-tab-sample", action="store_true", help="Print tab structure to stderr"
    )

    sub.add_parser(
        "sync",
        help="Write spaces.nix and pins.nix under home/.../zen/profiles/<name>/ (target from host or ZEN_OUTPUT_PROFILE; see scripts/zen-session README)",
    )
    sub.add_parser(
        "compare",
        help="Compare current flake spaces.nix/pins.nix with live session-derived state",
    )

    p = sub.add_parser("dump", help="Dump window session JSON")
    p.add_argument(
        "--full", action="store_true", help="Write full JSON to session_dump.json"
    )
    p.add_argument("--tabs", type=int, metavar="N", help="Tabs to print (default 3)")

    sub.add_parser(
        "check-spaces", help="Show where space names appear in session files"
    )

    args = ap.parse_args()
    if args.profile:
        os.environ["ZEN_PROFILE_ROOT"] = os.path.expanduser(args.profile)

    if args.command == "extract":
        from extract_pinned_tabs import main as run

        run(
            (["--nix"] if args.nix else [])
            + (["--zen-sessions-file", args.zen_sessions_file] if args.zen_sessions_file else [])
            + (
                ["--window-session-file", args.window_session_file]
                if args.window_session_file
                else []
            )
            + (["--dump-tab-sample"] if args.dump_tab_sample else [])
        )
    elif args.command == "sync":
        from sync_flake_profiles import main as run

        run()
    elif args.command == "compare":
        from sync_flake_profiles import compare_flake_to_session

        raise SystemExit(compare_flake_to_session())
    elif args.command == "dump":
        from dump_session import main as run

        dump_args = []
        if args.full:
            dump_args.append("--full")
        if args.tabs is not None:
            dump_args.extend(["--tabs", str(args.tabs)])
        run(dump_args)
    elif args.command == "check-spaces":
        from check_spaces import main as run

        run()


if __name__ == "__main__":
    main()
