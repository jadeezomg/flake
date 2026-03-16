#!/usr/bin/env python3
"""Dump window session JSON (recovery or sessionstore). Same source as extractor."""

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from extract_pinned_tabs import WINDOW_SESSION_PATHS, _read_mozlz4


def main(args=None):
    import argparse

    ap = argparse.ArgumentParser(description="Dump Zen window session structure")
    ap.add_argument(
        "--full", action="store_true", help="Write full JSON to session_dump.json"
    )
    ap.add_argument(
        "--tabs", type=int, default=3, metavar="N", help="Tabs to print (default 3)"
    )
    parsed = ap.parse_args(args)

    session = None
    used_path = None
    for path in WINDOW_SESSION_PATHS:
        if os.path.isfile(path):
            session = _read_mozlz4(path)
            if session and (session.get("windows") or []):
                used_path = path
                break

    if not session or not used_path:
        print(
            "No session with windows found. Tried:\n  "
            + "\n  ".join(WINDOW_SESSION_PATHS),
            file=sys.stderr,
        )
        sys.exit(2)

    print(f"# Read: {used_path}\n", file=sys.stderr)
    print("## Top-level keys")
    print(json.dumps(list(session.keys()), indent=2))

    for key in sorted(session.keys()):
        if (
            "space" in key.lower()
            or "essential" in key.lower()
            or "workspace" in key.lower()
            or "zen" in key.lower()
        ):
            val = session[key]
            if isinstance(val, (list, dict)) and len(str(val)) > 500:
                print(f"\n## session[{key!r}] (len {len(val)}, first 2)")
                print(
                    json.dumps(
                        (
                            val[:2]
                            if isinstance(val, list)
                            else dict(list(val.items())[:2])
                        ),
                        indent=2,
                        default=str,
                    )
                )
            else:
                print(f"\n## session[{key!r}]")
                print(json.dumps(val, indent=2, default=str))

    windows = session.get("windows") or []
    print(f"\n## windows: count = {len(windows)}")
    if windows:
        w = windows[0]
        print("\n## First window keys")
        print(json.dumps(list(w.keys()), indent=2))
        for k in ("workspaceID", "spaceId", "spaceName", "folders", "essentialTabIds"):
            if k in w:
                print(f"\n## First window [{k!r}]")
                print(json.dumps(w[k], indent=2, default=str))
        tabs = w.get("tabs") or []
        print(f"\n## First window tabs: count = {len(tabs)}")
        n = min(max(0, parsed.tabs), len(tabs))
        for i in range(n):
            t = tabs[i]
            print(f"\n## Tab[{i}]")
            print(json.dumps(t, indent=2, default=str))

    if parsed.full:
        out_path = os.path.join(os.path.dirname(__file__), "session_dump.json")
        with open(out_path, "w", encoding="utf-8") as f:
            json.dump(session, f, indent=2, default=str)
        print(f"\n## Full session written to {out_path}", file=sys.stderr)


if __name__ == "__main__":
    main()
