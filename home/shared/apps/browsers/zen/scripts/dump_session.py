#!/usr/bin/env python3
"""
Dump raw Zen session store JSON so we can see the exact structure (spaces, folders, essential, etc.).

Uses same profile path and session file order as extract_pinned_tabs (ZEN_PROFILE_ROOT, SESSION_PATHS).
Invoke via: uv run dump_session.py [--full] [--tabs N]  or  uv run zen_session.py dump [--full] [--tabs N]
"""
import json
import os
import sys

# Single source of truth: paths and session loading from extract_pinned_tabs
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from extract_pinned_tabs import SESSION_PATHS, _read_mozlz4


def main(args=None):
    import argparse
    ap = argparse.ArgumentParser(description="Dump raw Zen session store structure")
    ap.add_argument("--full", action="store_true", help="Write full session to session_dump.json")
    ap.add_argument("--tabs", type=int, default=3, metavar="N", help="Number of tabs to include in printed sample (default 3)")
    parsed = ap.parse_args(args)

    session = None
    used_path = None
    for path in SESSION_PATHS:
        if os.path.isfile(path):
            session = _read_mozlz4(path)
            if session is not None:
                used_path = path
                break

    if session is None:
        print(f"No session file found. Tried:\n  " + "\n  ".join(SESSION_PATHS), file=sys.stderr)
        sys.exit(2)

    print(f"# Read: {used_path}\n", file=sys.stderr)
    print("## Top-level keys")
    print(json.dumps(list(session.keys()), indent=2))

    # Print any key that might be spaces/essential at top level
    for key in sorted(session.keys()):
        if "space" in key.lower() or "essential" in key.lower() or "workspace" in key.lower() or "zen" in key.lower():
            val = session[key]
            if isinstance(val, (list, dict)) and len(str(val)) > 500:
                print(f"\n## session[{key!r}] (length {len(val)}, first 2 items)")
                if isinstance(val, list):
                    print(json.dumps(val[:2], indent=2, default=str))
                else:
                    items = list(val.items())[:2]
                    print(json.dumps(dict(items), indent=2, default=str))
            else:
                print(f"\n## session[{key!r}]")
                print(json.dumps(val, indent=2, default=str))

    windows = session.get("windows", [])
    print(f"\n## windows: count = {len(windows)}")

    if windows:
        w = windows[0]
        print("\n## First window keys")
        print(json.dumps(list(w.keys()), indent=2))
        for key in ("workspaceID", "spaceId", "spaceID", "spaceName", "spaceIcon", "folders", "essentialTabIds", "essentialTabs"):
            if key in w:
                print(f"\n## First window [{key!r}]")
                print(json.dumps(w[key], indent=2, default=str))

        tabs = w.get("tabs", [])
        print(f"\n## First window tabs: count = {len(tabs)}")

        n = max(0, min(parsed.tabs, len(tabs)))
        for i in range(n):
            t = tabs[i]
            print(f"\n## Tab[{i}] keys: {sorted(t.keys())}")
            print(json.dumps(t, indent=2, default=str))

    if parsed.full:
        out_path = os.path.join(os.path.dirname(__file__), "session_dump.json")
        with open(out_path, "w", encoding="utf-8") as f:
            json.dump(session, f, indent=2, default=str)
        print(f"\n## Full session written to {out_path}", file=sys.stderr)


if __name__ == "__main__":
    main()
