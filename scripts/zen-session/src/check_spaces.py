#!/usr/bin/env python3
"""Report where space names appear: zen-sessions (canonical) and window session."""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from extract_pinned_tabs import ZEN_SESSIONS_FILE, WINDOW_SESSION_PATHS, _read_mozlz4


def main(args=None):
    if os.path.isfile(ZEN_SESSIONS_FILE):
        data = _read_mozlz4(ZEN_SESSIONS_FILE)
        if data:
            spaces = data.get("spaces") or []
            print(f"zen-sessions: {ZEN_SESSIONS_FILE}")
            print(f"  spaces: len={len(spaces)}")
            for i, sp in enumerate(spaces[:5]):
                print(
                    f"    [{i}] uuid={sp.get('uuid') or sp.get('id')} name={sp.get('name') or sp.get('spaceName')}"
                )
        else:
            print(f"zen-sessions: {ZEN_SESSIONS_FILE} (read failed)")
    else:
        print(f"zen-sessions: {ZEN_SESSIONS_FILE} (missing)")

    for path in WINDOW_SESSION_PATHS:
        if not os.path.isfile(path):
            continue
        data = _read_mozlz4(path)
        if data is None:
            continue
        windows = data.get("windows") or []
        if not windows:
            continue
        print(f"window: {path}")
        for i, w in enumerate(windows[:2]):
            wid = w.get("workspaceID") or w.get("spaceId") or w.get("spaceID")
            print(f"  win[{i}] workspaceID={wid} spaceName={w.get('spaceName')}")
        break
    else:
        print("window: no file with windows found")


if __name__ == "__main__":
    main()
