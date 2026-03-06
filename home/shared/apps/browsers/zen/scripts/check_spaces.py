#!/usr/bin/env python3
"""Quick check: where are space names in session files?

Uses same profile path and session file order as extract_pinned_tabs (ZEN_PROFILE_ROOT, SESSION_PATHS).
Invoke via: uv run check_spaces.py  or  uv run zen_session.py check-spaces
"""
import os
import sys

# Single source of truth: paths and session loading from extract_pinned_tabs
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from extract_pinned_tabs import SESSION_PATHS, _read_mozlz4


# Keys we look for (aligned with extract_pinned_tabs._collect_spaces and _merge_spaces_from_session)
TOP_KEYS_SPACES = ("spaces", "workspaces", "spaceList", "zenSpaces")
NESTED_KEYS_SPACES = ("spaces", "workspaces", "spaceList", "zenSpaces", "sidebarData")
SIDEBAR_SPACES = "sidebar"  # Zen: sidebar.spaces is canonical


def main(args=None):
    for path in SESSION_PATHS:
        if not os.path.isfile(path):
            print("skip", path)
            continue
        s = _read_mozlz4(path)
        if s is None:
            print("bad read", path)
            continue
        print("File:", path)
        print("  top keys:", list(s.keys())[:15])
        print("  'spaces' in top:", "spaces" in s)
        if s.get("spaces"):
            for i, sp in enumerate(s["spaces"][:3]):
                print("  top spaces[%d]:" % i, sp)
        if s.get(SIDEBAR_SPACES) and isinstance(s.get(SIDEBAR_SPACES), dict):
            arr = s[SIDEBAR_SPACES].get("spaces")
            if arr is not None:
                print("  sidebar.spaces:", "list" if isinstance(arr, list) else "dict", "len=" if isinstance(arr, (list, dict)) else "", len(arr) if isinstance(arr, (list, dict)) else "")
                if isinstance(arr, list) and arr:
                    print("  sidebar.spaces[0]:", arr[0])
        for key in ("session", "global"):
            node = s.get(key)
            if isinstance(node, dict):
                sub = {k: node[k] for k in list(node.keys())[:20]}
                print("  %s keys:" % key, list(sub.keys()))
                for sk in NESTED_KEYS_SPACES:
                    if sk in node:
                        val = node[sk]
                        if isinstance(val, list):
                            print("  %s.%s: list len=%d" % (key, sk, len(val)), val[:3] if len(val) <= 3 else val[:2], "..." if len(val) > 3 else "")
                        else:
                            print("  %s.%s:" % (key, sk), val)
        for i, w in enumerate((s.get("windows") or [])[:2]):
            print("  win[%d].spaces present:" % i, "spaces" in w, "len:", len(w.get("spaces") or []))
            if w.get("spaces"):
                for j, sp in enumerate(w["spaces"][:3]):
                    print("    win[%d].spaces[%d]:" % (i, j), sp)
            print("  win[%d].workspaceID:" % i, w.get("workspaceID"))
            for key in ("session", "global"):
                node = w.get(key)
                if isinstance(node, dict) and ("space" in str(node.keys()).lower() or "workspace" in str(node.keys()).lower()):
                    print("  win[%d].%s keys with space:" % (i, key), [k for k in node if "space" in k.lower() or "workspace" in k.lower()])


if __name__ == "__main__":
    main()
