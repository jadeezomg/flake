#!/usr/bin/env python3
"""Single entry point for Zen session scripts. Override profile with --profile / -p."""

import os


def main():
    import argparse

    ap = argparse.ArgumentParser(
        prog="zen-session",
        description="Zen session tools (extract, sync, compare)",
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
        help="Write spaces.nix and pins.nix under home/.../zen/profiles/<name>/ (target from host or ZEN_OUTPUT_PROFILE; see scripts README)",
    )
    sub.add_parser(
        "compare",
        help="Compare current flake spaces.nix/pins.nix with live session-derived state",
    )

    args = ap.parse_args()
    if args.profile:
        os.environ["ZEN_PROFILE_ROOT"] = os.path.expanduser(args.profile)

    if args.command == "extract":
        from flake_scripts.zen.extract_pinned_tabs import main as run

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
        from flake_scripts.zen.sync_flake_profiles import main as run

        run()
    elif args.command == "compare":
        from flake_scripts.zen.sync_flake_profiles import compare_flake_to_session

        raise SystemExit(compare_flake_to_session())


if __name__ == "__main__":
    main()
