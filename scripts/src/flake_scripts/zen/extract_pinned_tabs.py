#!/usr/bin/env python3
"""
Extract pinned tabs per workspace from Zen's session store.

Data sources:
- zen-sessions.jsonlz4  → spaces (name, icon, position). Root .spaces is the sidebar list.
- Windows/tabs: recovery.jsonlz4, then sessionstore.jsonlz4, then zen-sessions.jsonlz4 (first that exists and has .windows). When Zen is closed, only zen-sessions may be present.

  uv run extract_pinned_tabs.py [--nix]

Browser profile path: macOS default profile dir, Linux $XDG_CONFIG_HOME/zen/default (set ZEN_PROFILE_ROOT or --profile to override).
"""

import argparse
import json
import os
import re
import sys
import uuid
from collections import Counter
from typing import Any, cast

from flake_scripts.lib.common import bad, dim, dim_lines, warn, xdg_config_home

try:
    import lz4.block
except ImportError:
    bad("Missing lz4 — run [bold]uv sync[/] in scripts/", stderr=True)
    sys.exit(1)


def _default_zen_profile_root():
    if sys.platform == "darwin":
        return os.path.expanduser("~/Library/Application Support/zen/Profiles/default")
    zen_root = xdg_config_home() / "zen"
    primary = zen_root / "default"
    if (primary / "zen-sessions.jsonlz4").is_file():
        return str(primary)
    if zen_root.is_dir():
        for cand in sorted(zen_root.iterdir()):
            if cand.is_dir() and (cand / "zen-sessions.jsonlz4").is_file():
                return str(cand)
    return str(primary)


# Browser profile root: env ZEN_PROFILE_ROOT, else platform default (see _default_zen_profile_root)
ZEN_PROFILE_ROOT = os.environ.get("ZEN_PROFILE_ROOT", _default_zen_profile_root())
# Spaces: zen-sessions.jsonlz4 root = sidebar { spaces: [{ uuid, name, icon, position }] }
ZEN_SESSIONS_FILE = os.path.join(ZEN_PROFILE_ROOT, "zen-sessions.jsonlz4")
# Windows/tabs: recovery first, then sessionstore, then zen-sessions (present when Zen is closed)
SESSIONSTORE_RECOVERY = os.path.join(
    ZEN_PROFILE_ROOT, "sessionstore-backups", "recovery.jsonlz4"
)
SESSIONSTORE_MAIN = os.path.join(ZEN_PROFILE_ROOT, "sessionstore.jsonlz4")
WINDOW_SESSION_PATHS = [SESSIONSTORE_RECOVERY, SESSIONSTORE_MAIN, ZEN_SESSIONS_FILE]
# All session-related paths (session inspection / tooling)
SESSION_PATHS = [ZEN_SESSIONS_FILE] + WINDOW_SESSION_PATHS
# Optional override: JSON mapping space ID -> name or { name, icon?, position? }
ZEN_SPACE_NAMES_FILE = os.environ.get(
    "ZEN_SPACE_NAMES_FILE",
    os.path.join(ZEN_PROFILE_ROOT, "space_names.json"),
)
SKIP_URL_PREFIXES = ("about:blank", "about:")

_UUID_RE = re.compile(r"^[0-9a-f\-]{36}$", re.I)
# Firefox / Zen live-folder ids: "{<ms>-<seq>}"; repeated syncs can accumulate extra braces.
_FOLDER_NUMERIC_ID_RE = re.compile(r"^(\d+-\d+)$")


def normalize_zen_folder_id(raw):
    """Strip nested `{`/`}` from round-tripped skifli/Nix state; canonicalize for pins.nix.

    Returns ``{timestamp-seq}`` for numeric folder ids (single brace pair, matching a
    fresh session), lowercase UUID string without braces for UUID-shaped ids, else the
    stripped inner string.
    """
    if raw is None:
        return None
    s = str(raw).strip()
    if not s:
        return s
    inner = s
    while len(inner) >= 2 and inner.startswith("{") and inner.endswith("}"):
        inner = inner[1:-1].strip()
    if not inner:
        return s
    if _UUID_RE.match(inner):
        return inner.lower()
    if _FOLDER_NUMERIC_ID_RE.match(inner):
        return "{" + inner + "}"
    return inner


def _read_mozlz4(path):
    with open(path, "rb") as f:
        data = f.read()
    if data[:8] != b"mozLz40\x00":
        return None
    return json.loads(lz4.block.decompress(data[8:]).decode("utf-8"))


def _load_zen_sessions(zen_sessions_file=None):
    """Load a Zen `zen-sessions*.jsonlz4` file.

    This is used both for the sidebar `.spaces` list and (when closed) can also
    include windows/tabs data.
    """
    if zen_sessions_file is None:
        zen_sessions_file = ZEN_SESSIONS_FILE
    if not os.path.isfile(zen_sessions_file):
        bad(f"Missing: {zen_sessions_file}", stderr=True)
        sys.exit(2)
    data = _read_mozlz4(zen_sessions_file)
    if data is None:
        bad(f"Invalid or empty: {zen_sessions_file}", stderr=True)
        sys.exit(2)
    return data


def _load_window_session(window_session_paths=None, return_used_path=False):
    """Load session that has windows/tabs.

    If return_used_path is true, returns (data, used_path).
    """
    if window_session_paths is None:
        window_session_paths = WINDOW_SESSION_PATHS

    for path in window_session_paths:
        if not os.path.isfile(path):
            continue
        data = _read_mozlz4(path)
        if data is None:
            continue
        windows = data.get("windows") or []
        if windows:
            return (data, path) if return_used_path else data
    bad("No session with windows found.", stderr=True)
    dim_lines(*[f"  {p}" for p in window_session_paths])
    dim_lines(
        "(When Zen is closed, a zen-sessions*.jsonlz4 backup may still have window/tab data.)",
    )
    sys.exit(2)


def _normalize_zen_workspace(s):
    if not s:
        return ""
    s = str(s).strip()
    if s.startswith("{") and s.endswith("}"):
        s = s[1:-1]
    return s.lower() if s else ""


def _spaces_from_zen_sessions(zen_sessions):
    """Build space_id -> { name, icon, position } from zen-sessions root .spaces only."""
    out = {}
    for s in zen_sessions.get("spaces") or []:
        if not isinstance(s, dict):
            continue
        sid = _normalize_zen_workspace(s.get("uuid") or "")
        if not sid or not _UUID_RE.match(sid):
            continue
        name = (s.get("name") or "").strip()
        icon = (s.get("icon") or "").strip()
        pos = s.get("position")
        out[sid] = {"name": name or "Default", "icon": icon, "position": pos}
    return out


def _apply_space_names_override(spaces_map):
    """If space_names.json exists, override names (and optionally icon/position) in spaces_map."""
    if not os.path.isfile(ZEN_SPACE_NAMES_FILE):
        return
    try:
        with open(ZEN_SPACE_NAMES_FILE, encoding="utf-8") as f:
            custom = json.load(f)
    except (OSError, json.JSONDecodeError):
        return
    if not isinstance(custom, dict):
        return
    for sid_raw, val in custom.items():
        sid = _normalize_zen_workspace(str(sid_raw)) or str(sid_raw).strip()
        if not sid or sid not in spaces_map:
            continue
        entry = spaces_map[sid]
        if isinstance(val, dict):
            if val.get("name"):
                entry["name"] = val["name"].strip()
            if val.get("icon") is not None:
                entry["icon"] = str(val["icon"]).strip()
            if val.get("position") is not None:
                entry["position"] = val["position"]
        elif val:
            entry["name"] = str(val).strip()


def _normalize_url(url):
    if not url:
        return None
    if isinstance(url, list):
        url = url[-1] if url else None
    return (url.strip() or None) if isinstance(url, str) else None


def _should_skip_url(url):
    return not url or any(url.startswith(p) for p in SKIP_URL_PREFIXES)


def _tab_id(t):
    """tab.zenSyncId is the canonical tab identifier (UUID with braces, e.g. {abc-…})."""
    tid = t.get("zenSyncId")
    return _normalize_zen_workspace(str(tid)) if tid is not None else None


def _folders_from_window(w: dict[str, Any], spaces_map: dict):
    """window.folders -> (folder_id -> name map, list of full folder records)."""
    folder_map = {}
    records = []
    folders = w.get("folders")
    if not folders:
        return folder_map, records

    def one(fid, attrs, idx):
        name = (
            (attrs.get("name") or "Folder").strip()
            if isinstance(attrs, dict)
            else "Folder"
        )
        parent_id = attrs.get("parentId") if isinstance(attrs, dict) else None
        pos = attrs.get("position") if isinstance(attrs, dict) else None
        if (
            pos is None
            and isinstance(attrs, dict)
            and isinstance(attrs.get("prevSiblingInfo"), dict)
        ):
            pos = attrs["prevSiblingInfo"].get("position")
        nid = normalize_zen_folder_id(str(fid)) if fid else ""
        pid = normalize_zen_folder_id(str(parent_id)) if parent_id is not None else None
        return {
            "id": nid or str(fid),
            "name": name or "Folder",
            "parentId": pid,
            "position": int(pos) if pos is not None else 1000 + idx,
            "spaceId": "",
            "spaceName": "Default",
        }

    if isinstance(folders, dict):
        for idx, (fid, attrs) in enumerate(folders.items()):
            if fid:
                rec = one(fid, attrs if isinstance(attrs, dict) else {}, idx)
                folder_map[rec["id"]] = rec["name"]
                records.append(rec)
    elif isinstance(folders, list):
        for idx, f in enumerate(folders):
            if not isinstance(f, dict):
                continue
            fd = cast(dict[str, Any], f)
            if fd.get("id"):
                rec = one(fd["id"], fd, idx)
                folder_map[rec["id"]] = rec["name"]
                records.append(rec)

    return folder_map, records


def _collect_pinned_tabs(tabs):
    """Walk tab list (recursing into .children); yield (tab, url, entry) for pinned tabs."""
    for t in tabs or []:
        if t.get("pinned"):
            entries = t.get("entries") or [{}]
            ent = entries[0] if entries else {}
            url = _normalize_url(ent.get("url"))
            if url and not _should_skip_url(url):
                yield t, url, ent
        yield from _collect_pinned_tabs(t.get("children") or [])


def _tab_pins_from_tabs(tabs, folder_map):
    """Yield pin dicts from window.tabs. tab.zenWorkspace for space; groupId/zenLiveFolderItemId for folder."""
    for t, url, ent in _collect_pinned_tabs(tabs):
        title = (ent.get("title") or "").strip() or None
        parent_id = t.get("groupId") or t.get("zenLiveFolderItemId")
        pin_folder = None
        if parent_id is not None:
            parent_id = normalize_zen_folder_id(str(parent_id))
            pin_folder = folder_map.get(parent_id) if parent_id else None
        space_id = _normalize_zen_workspace(t.get("zenWorkspace") or "")
        container_id = t.get("userContextId") or ent.get("userContextId")
        if container_id is not None:
            try:
                container_id = int(container_id)
            except (TypeError, ValueError):
                container_id = None
        if container_id == 0:
            container_id = None
        pin = {
            "title": title,
            "url": url,
            "isEssential": bool(t.get("zenEssential")),
            "folder": pin_folder,
            "folderId": parent_id,
            "tabId": _tab_id(t),
            "spaceId": space_id,
        }
        if container_id is not None:
            pin["containerId"] = container_id
        yield pin


def nix_escape(s):
    return (s or "").replace("\\", "\\\\").replace('"', '\\"')


def slug(title, url):
    if title and re.match(r"^[\w\s\-]+$", (title or "")[:30]):
        return re.sub(r"\s+", " ", (title or "").strip())[:40]
    if url:
        try:
            from urllib.parse import urlparse

            host = (
                (urlparse(url).netloc or "tab").split(".")[-2]
                if urlparse(url).netloc
                else "tab"
            )
            return host.capitalize()
        except Exception:
            pass
    return "Tab"


def iter_space_nix_rows(spaces_list: list[dict]) -> list[tuple[str, str, str, int]]:
    """Nix `spaces` attrs: (nix_key, id, icon_escaped, position) per Zen space."""
    used: set[str] = set()
    rows: list[tuple[str, str, str, int]] = []
    for i, s in enumerate(spaces_list):
        raw = s.get("name")
        name = (raw or "").strip() if isinstance(raw, str) else ""
        if not name:
            name = "Default"
        sid = str(s.get("id") or "")
        key = nix_escape(name)
        if key in used:
            key = nix_escape(f"{name} ({sid[:8]})")
        used.add(key)
        pos = s.get("position")
        if pos is None or pos == 0 or (isinstance(pos, (int, float)) and pos == 0):
            pos = 1000 + i
        icon_val = nix_escape(str(s.get("icon") or "").strip())
        rows.append((key, sid, icon_val, int(pos)))
    return rows


def space_id_to_nix_keys(spaces_list: list[dict]) -> dict[str, str]:
    """Map Zen space id → Nix spaces attr key (same rules as iter_space_nix_rows)."""
    return {sid: key for key, sid, _, _ in iter_space_nix_rows(spaces_list)}


def normalize_zen_tab_id(tab_id) -> str:
    """Lowercase UUID for Nix pin `id`; replace invalid values with a new uuid4."""
    if tab_id is None or tab_id == "":
        candidate = str(uuid.uuid4()).lower()
    else:
        candidate = str(tab_id).lower()
    if not _UUID_RE.match(candidate):
        return str(uuid.uuid4()).lower()
    return candidate


def load_pinned_per_space(zen_sessions=None, window_session=None):
    """
    Extract spaces, pins per space, and folders. Uses exactly:
    - zen_sessions (zen-sessions.jsonlz4) for space list
    - window_session (recovery or sessionstore) for windows/tabs/folders
    """
    if zen_sessions is None:
        zen_sessions = _load_zen_sessions()
    if window_session is None:
        window_session = _load_window_session()

    spaces_map = _spaces_from_zen_sessions(zen_sessions)
    _apply_space_names_override(spaces_map)

    all_folders = {}
    space_pins = {}
    for w in window_session.get("windows") or []:
        folder_map, folder_recs = _folders_from_window(w, spaces_map)
        for rec in folder_recs:
            if rec["id"] not in all_folders:
                all_folders[rec["id"]] = rec
        for pin in _tab_pins_from_tabs(w.get("tabs") or [], folder_map):
            sid = pin.get("spaceId") or "default"
            space_pins.setdefault(sid, []).append(pin)

    for space_id in space_pins:
        if space_id and space_id not in spaces_map:
            spaces_map[space_id] = {"name": "Default", "icon": "", "position": None}

    for fid, rec in all_folders.items():
        pin_spaces = [
            sid
            for sid, pins in space_pins.items()
            for p in pins
            if (p.get("folderId") or "") == fid
        ]
        if pin_spaces:
            best = Counter(pin_spaces).most_common(1)[0][0]
            rec["spaceId"] = best
            rec["spaceName"] = (spaces_map.get(best) or {}).get("name") or "Default"

    spaces_list = [
        {
            "id": sid,
            "name": attrs.get("name") or "Default",
            "icon": attrs.get("icon") or "",
            "position": attrs.get("position"),
        }
        for sid, attrs in sorted(
            spaces_map.items(), key=lambda x: (x[1].get("position") or 0, x[0])
        )
    ]
    out_windows = [
        {
            "spaceId": sid,
            "spaceName": (spaces_map.get(sid) or {}).get("name") or "Default",
            "pins": pins,
        }
        for sid, pins in sorted(space_pins.items())
    ]
    return {
        "spaces": spaces_list,
        "windows": out_windows,
        "folders": list(all_folders.values()),
    }


def main(args=None):
    ap = argparse.ArgumentParser(description="Extract Zen pinned tabs per workspace")
    ap.add_argument("--nix", action="store_true", help="Print Nix pins snippet")
    ap.add_argument(
        "--zen-sessions-file",
        metavar="PATH",
        help="Use a specific zen-sessions*.jsonlz4 file (e.g. from zen-sessions-backup/).",
    )
    ap.add_argument(
        "--window-session-file",
        metavar="PATH",
        help="Use a specific session*.jsonlz4 file for windows/tabs (e.g. sessionstore-backups/recovery*.jsonlz4).",
    )
    ap.add_argument(
        "--dump-tab-sample", action="store_true", help="Print tab structure to stderr"
    )
    args = ap.parse_args(args)

    zen_sessions_file = (
        os.path.expanduser(args.zen_sessions_file)
        if args.zen_sessions_file
        else ZEN_SESSIONS_FILE
    )

    zen_sessions = _load_zen_sessions(zen_sessions_file=zen_sessions_file)
    zen_sessions_has_windows = bool(zen_sessions.get("windows"))

    if args.window_session_file:
        window_session_paths = [os.path.expanduser(args.window_session_file)]
    else:
        # zen-sessions backups typically include spaces only; windows/tabs are
        # usually in sessionstore-backups/*.jsonlz4.
        window_session_paths = (
            [zen_sessions_file, SESSIONSTORE_RECOVERY, SESSIONSTORE_MAIN]
            if zen_sessions_has_windows
            else [SESSIONSTORE_RECOVERY, SESSIONSTORE_MAIN, zen_sessions_file]
        )

    window_session, used_window_session_path = _load_window_session(
        window_session_paths=window_session_paths, return_used_path=True
    )

    if args.zen_sessions_file and not zen_sessions_has_windows:
        # Explain why the output may look like the "current session".
        if used_window_session_path != zen_sessions_file:
            warn(
                f"{zen_sessions_file} has windows=[]; using tabs from {used_window_session_path}.",
                stderr=True,
            )

    if args.dump_tab_sample:
        for i, w in enumerate((window_session.get("windows") or [])[:2]):
            tabs = w.get("tabs") or []
            dim(f"Window {i}: {len(tabs)} tabs", stderr=True)
            for j, t in enumerate(tabs[:6]):
                dim(
                    f"  Tab {j}: pinned={t.get('pinned')} zenWorkspace={t.get('zenWorkspace')} "
                    f"groupId={t.get('groupId')} zenEssential={t.get('zenEssential')}",
                    stderr=True,
                )
        if not args.nix:
            return

    out = load_pinned_per_space(
        zen_sessions=zen_sessions, window_session=window_session
    )
    spaces_list, windows = out["spaces"], out["windows"]

    if args.nix:
        lines = []
        if spaces_list:
            lines.append("  spaces = {")
            for key, sid, icon_val, pos in iter_space_nix_rows(spaces_list):
                lines.append(
                    f'    "{key}" = {{ id = "{sid}"; icon = "{icon_val}"; position = {pos}; }};'
                )
            lines.append("  };")
            lines.append("")
        pos = 101
        lines.append("  pins = {")
        seen_urls, used_keys = set(), set()
        for group in windows:
            lines.append(f"    # {(group.get('spaceName') or 'Default')}")
            for p in group["pins"]:
                url = p["url"]
                if url in seen_urls:
                    continue
                seen_urls.add(url)
                title = p.get("title") or slug(None, url)
                base_key = slug(title, url)
                key = base_key
                c = 0
                while key in used_keys:
                    c += 1
                    key = f"{base_key}_{c}"
                used_keys.add(key)
                pin_id = normalize_zen_tab_id(p.get("tabId"))
                parts = [
                    f'id = "{pin_id}"',
                    f'url = "{nix_escape(url)}"',
                    f"position = {pos}",
                    f"isEssential = {'true' if p.get('isEssential') else 'false'}",
                ]
                if p.get("containerId"):
                    parts.append(f"containerId = {int(p['containerId'])}")
                lines.append(
                    f'    "{nix_escape(title or key)}" = {{ {"; ".join(parts)}; }};'
                )
                pos += 1
            lines.append("")
        lines.append("  };")
        print("\n".join(lines))
    else:
        print(json.dumps(out, indent=2))


if __name__ == "__main__":
    main()
