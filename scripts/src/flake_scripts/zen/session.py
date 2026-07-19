"""Read Zen browser session files (mozLz4) and extract spaces, pins, and folders."""

from __future__ import annotations

import json
import os
import re
import sys
import uuid
from collections import Counter
from typing import Any, cast
from urllib.parse import urlparse

from flake_scripts.lib.common import bad, dim_lines, xdg_config_home

try:
    import lz4.block
except ImportError:
    bad("Missing lz4 — run [bold]uv sync[/] in scripts/", stderr=True)
    sys.exit(1)

SKIP_URL_PREFIXES = ("about:blank", "about:")
_UUID_RE = re.compile(r"^[0-9a-f\-]{36}$", re.I)
_FOLDER_NUMERIC_ID_RE = re.compile(r"^(\d+-\d+)$")


def _default_zen_profile_root() -> str:
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


ZEN_PROFILE_ROOT = os.environ.get("ZEN_PROFILE_ROOT", _default_zen_profile_root())
ZEN_SESSIONS_FILE = os.path.join(ZEN_PROFILE_ROOT, "zen-sessions.jsonlz4")
SESSIONSTORE_RECOVERY = os.path.join(
    ZEN_PROFILE_ROOT, "sessionstore-backups", "recovery.jsonlz4"
)
SESSIONSTORE_MAIN = os.path.join(ZEN_PROFILE_ROOT, "sessionstore.jsonlz4")
WINDOW_SESSION_PATHS = [SESSIONSTORE_RECOVERY, SESSIONSTORE_MAIN, ZEN_SESSIONS_FILE]


def normalize_zen_folder_id(raw: object) -> str | None:
    """Canonicalize folder ids for pins.nix (brace-wrapped numeric or lowercase UUID)."""
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


def _read_mozlz4(path: str) -> dict[str, Any] | None:
    with open(path, "rb") as f:
        data = f.read()
    if data[:8] != b"mozLz40\x00":
        return None
    return json.loads(lz4.block.decompress(data[8:]).decode("utf-8"))


def _load_zen_sessions(zen_sessions_file: str | None = None) -> dict[str, Any]:
    path = zen_sessions_file or ZEN_SESSIONS_FILE
    if not os.path.isfile(path):
        bad(f"Missing: {path}", stderr=True)
        sys.exit(2)
    data = _read_mozlz4(path)
    if data is None:
        bad(f"Invalid or empty: {path}", stderr=True)
        sys.exit(2)
    return data


def _load_window_session(
    window_session_paths: list[str] | None = None,
) -> dict[str, Any]:
    paths = window_session_paths or WINDOW_SESSION_PATHS
    for path in paths:
        if not os.path.isfile(path):
            continue
        data = _read_mozlz4(path)
        if data is None:
            continue
        if data.get("windows"):
            return data
    bad("No session with windows found.", stderr=True)
    dim_lines(*[f"  {p}" for p in paths])
    sys.exit(2)


def _normalize_zen_workspace(s: object) -> str:
    if not s:
        return ""
    text = str(s).strip()
    if text.startswith("{") and text.endswith("}"):
        text = text[1:-1]
    return text.lower() if text else ""


def _spaces_from_zen_sessions(
    zen_sessions: dict[str, Any],
) -> dict[str, dict[str, Any]]:
    out: dict[str, dict[str, Any]] = {}
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


def _normalize_url(url: object) -> str | None:
    if not url:
        return None
    if isinstance(url, list):
        url = url[-1] if url else None
    return (url.strip() or None) if isinstance(url, str) else None


def _should_skip_url(url: str | None) -> bool:
    return not url or any(url.startswith(p) for p in SKIP_URL_PREFIXES)


def _tab_id(t: dict[str, Any]) -> str | None:
    tid = t.get("zenSyncId")
    return _normalize_zen_workspace(str(tid)) if tid is not None else None


def _folders_from_window(w: dict[str, Any]) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    folders = w.get("folders")
    if not folders:
        return records

    def one(fid: object, attrs: dict[str, Any], idx: int) -> dict[str, Any]:
        name = (attrs.get("name") or "Folder").strip()
        parent_id = attrs.get("parentId")
        pos = attrs.get("position")
        prev_sibling = attrs.get("prevSiblingInfo")
        if pos is None and isinstance(prev_sibling, dict):
            pos = prev_sibling.get("position")
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
        for idx, (fid, raw_attrs) in enumerate(folders.items()):
            if fid:
                attrs: dict[str, Any] = (
                    cast(dict[str, Any], raw_attrs)
                    if isinstance(raw_attrs, dict)
                    else {}
                )
                records.append(one(fid, attrs, idx))
    elif isinstance(folders, list):
        for idx, f in enumerate(folders):
            if not isinstance(f, dict):
                continue
            fd = cast(dict[str, Any], f)
            if fd.get("id"):
                records.append(one(fd["id"], fd, idx))

    return records


def _pins_from_tabs(tabs: list[dict[str, Any]] | None):
    for t in tabs or []:
        if t.get("pinned"):
            entries = t.get("entries") or [{}]
            ent = entries[0] if entries else {}
            url = _normalize_url(ent.get("url"))
            if url and not _should_skip_url(url):
                title = (ent.get("title") or t.get("title") or "").strip() or None
                parent_id = t.get("groupId") or t.get("zenLiveFolderItemId")
                if parent_id is not None:
                    parent_id = normalize_zen_folder_id(str(parent_id))
                space_id = _normalize_zen_workspace(t.get("zenWorkspace") or "")
                container_id = t.get("userContextId") or ent.get("userContextId")
                if container_id is not None:
                    try:
                        container_id = int(container_id)
                    except (TypeError, ValueError):
                        container_id = None
                if container_id == 0:
                    container_id = None
                pin: dict[str, Any] = {
                    "title": title,
                    "url": url,
                    "isEssential": bool(t.get("zenEssential")),
                    "folderId": parent_id,
                    "tabId": _tab_id(t),
                    "spaceId": space_id,
                }
                if container_id is not None:
                    pin["containerId"] = container_id
                yield pin
        yield from _pins_from_tabs(t.get("children") or [])


def nix_escape(s: str | None) -> str:
    return (s or "").replace("\\", "\\\\").replace('"', '\\"')


def slug(title: str | None, url: str) -> str:
    if title and re.match(r"^[\w\s\-]+$", (title or "")[:30]):
        return re.sub(r"\s+", " ", (title or "").strip())[:40]
    if url:
        try:
            netloc = urlparse(url).netloc
            host = (netloc or "tab").split(".")[-2] if netloc else "tab"
            return host.capitalize()
        except Exception:
            pass
    return "Tab"


def iter_space_nix_rows(
    spaces_list: list[dict[str, Any]],
) -> list[tuple[str, str, str, int]]:
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


def normalize_zen_tab_id(tab_id: object) -> str:
    if tab_id is None or tab_id == "":
        candidate = str(uuid.uuid4()).lower()
    else:
        candidate = str(tab_id).lower()
    if not _UUID_RE.match(candidate):
        return str(uuid.uuid4()).lower()
    return candidate


def load_pinned_per_space(
    zen_sessions: dict[str, Any] | None = None,
    window_session: dict[str, Any] | None = None,
) -> dict[str, Any]:
    if zen_sessions is None:
        zen_sessions = _load_zen_sessions()
    if window_session is None:
        window_session = _load_window_session()

    spaces_map = _spaces_from_zen_sessions(zen_sessions)
    all_folders: dict[str, dict[str, Any]] = {}
    space_pins: dict[str, list[dict[str, Any]]] = {}
    for w in window_session.get("windows") or []:
        for rec in _folders_from_window(w):
            if rec["id"] not in all_folders:
                all_folders[rec["id"]] = rec
        for pin in _pins_from_tabs(w.get("tabs") or []):
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
