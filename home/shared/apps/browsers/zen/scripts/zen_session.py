#!/usr/bin/env python3
"""
Single entry point for Zen session scripts. All commands use the same profile path and session
file order (from extract_pinned_tabs). Use --profile to override ZEN_PROFILE_ROOT.

  uv run zen_session.py -p "~/Library/Application Support/zen/Profiles/default" extract --nix
  uv run zen_session.py sync
  uv run zen_session.py dump --full --tabs 5
  uv run zen_session.py check-spaces

Or run the individual scripts (they share the same config):
  uv run extract_pinned_tabs.py --nix
  uv run sync_caya_from_session.py
  uv run dump_session.py --full
  uv run check_spaces.py
"""
import os
import sys

_SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if _SCRIPT_DIR not in sys.path:
    sys.path.insert(0, _SCRIPT_DIR)


def _apply_profile(profile_path):
    if profile_path:
        os.environ["ZEN_PROFILE_ROOT"] = os.path.expanduser(profile_path)


def cmd_extract(args, profile):
    _apply_profile(profile)
    from extract_pinned_tabs import main as extract_main
    extract_args = (["--nix"] if args.nix else []) + (["--dump-tab-sample"] if args.dump_tab_sample else [])
    extract_main(extract_args)


def cmd_sync(args, profile):
    _apply_profile(profile)
    from sync_caya_from_session import main as sync_main
    sync_main()


def cmd_dump(args, profile):
    _apply_profile(profile)
    from dump_session import main as dump_main
    dump_args = []
    if args.full:
        dump_args.append("--full")
    if args.tabs is not None:
        dump_args.extend(["--tabs", str(args.tabs)])
    dump_main(dump_args)


def cmd_check_spaces(args, profile):
    _apply_profile(profile)
    from check_spaces import main as check_main
    check_main()


def main():
    import argparse
    ap = argparse.ArgumentParser(
        description="Zen session tools (extract, sync, dump, check-spaces). Shared config from extract_pinned_tabs.",
        prog="zen_session.py",
    )
    ap.add_argument(
        "--profile", "-p",
        default=os.environ.get("ZEN_PROFILE_ROOT", ""),
        metavar="DIR",
        help="Zen profile directory (default: ZEN_PROFILE_ROOT or ~/Library/Application Support/zen/Profiles/default)",
    )
    sub = ap.add_subparsers(dest="command", required=True)

    # extract
    p_extract = sub.add_parser("extract", help="Extract pinned tabs per workspace (print JSON or Nix)")
    p_extract.add_argument("--nix", action="store_true", help="Print Nix pins snippet")
    p_extract.add_argument("--dump-tab-sample", action="store_true", help="Print tab structure to stderr")
    p_extract.set_defaults(func=cmd_extract)

    # sync
    p_sync = sub.add_parser("sync", help="Update profiles/caya/spaces.nix, essentials.nix, pins.nix from live session")
    p_sync.set_defaults(func=cmd_sync)

    # dump
    p_dump = sub.add_parser("dump", help="Dump raw session JSON structure")
    p_dump.add_argument("--full", action="store_true", help="Write full session to session_dump.json")
    p_dump.add_argument("--tabs", type=int, default=None, metavar="N", help="Number of tabs in printed sample (default 3)")
    p_dump.set_defaults(func=cmd_dump)

    # check-spaces
    p_check = sub.add_parser("check-spaces", help="Show where space names appear in session files")
    p_check.set_defaults(func=cmd_check_spaces)

    args = ap.parse_args()
    profile = args.profile or None
    args.func(args, profile)


if __name__ == "__main__":
    main()
