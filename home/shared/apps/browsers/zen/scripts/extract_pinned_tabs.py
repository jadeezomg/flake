#!/usr/bin/env python3
"""
Extract pinned tabs per workspace from Zen's session store.

  uv run extract_pinned_tabs.py [--nix]   # from scripts/ dir (uv installs lz4)

Profile path (default on macOS): ~/Library/Application Support/zen/Profiles/default
"""
import argparse
import json
import os
import re
import sys
import uuid

try:
    import lz4.block
except ImportError:
    print("Install lz4: pip install lz4", file=sys.stderr)
    sys.exit(1)

# Default profile path (macOS)
ZEN_PROFILE_ROOT = os.environ.get(
    "ZEN_PROFILE_ROOT",
    os.path.expanduser("~/Library/Application Support/zen/Profiles/default"),
)
# zen-sessions.jsonlz4 root = sidebar object { spaces, tabs, folders, ... } (ZenSessionManager.sys.mjs).
# So spaces with name/icon live in zen-sessions; recovery.jsonlz4 has windows/tabs but not the spaces list.
ZEN_SESSIONS_FILE = os.path.join(ZEN_PROFILE_ROOT, "zen-sessions.jsonlz4")
ZEN_SESSIONS_BACKUP_DIR = os.path.join(ZEN_PROFILE_ROOT, "zen-sessions-backup")
SESSIONSTORE_MAIN = os.path.join(ZEN_PROFILE_ROOT, "sessionstore.jsonlz4")
SESSIONSTORE_RECOVERY = os.path.join(
    ZEN_PROFILE_ROOT, "sessionstore-backups", "recovery.jsonlz4"
)
# Order: load a session that has "windows" first (recovery/sessionstore), so we get pins.
# Space names/icons are then merged from zen-sessions.jsonlz4 (root = sidebar with .spaces).
SESSION_PATHS = [SESSIONSTORE_MAIN, SESSIONSTORE_RECOVERY, ZEN_SESSIONS_FILE]
# Optional: JSON file mapping space ID -> name or {name, icon?, position?} when session has no names
ZEN_SPACE_NAMES_FILE = os.environ.get(
    "ZEN_SPACE_NAMES_FILE",
    os.path.join(ZEN_PROFILE_ROOT, "space_names.json"),
)
# Skip these URLs (sign-in redirects, blank, etc.)
SKIP_URL_PREFIXES = (
    "about:blank",
    "about:",
    "https://accounts.google.com/",  # sign-in redirects
)


def _normalize_url(url):
    """Get a single URL string from entry; session store may have url as string or list (history)."""
    if not url:
        return None
    if isinstance(url, list):
        url = url[-1] if url else None
    if not url or not isinstance(url, str):
        return None
    return url.strip() or None


def _should_skip_url(url):
    if not url:
        return True
    return any(url.startswith(prefix) for prefix in SKIP_URL_PREFIXES)


def _normalize_zen_workspace(s):
    """Normalize Zen workspace ID: strip surrounding braces, return lower UUID or empty string."""
    if not s:
        return ""
    s = str(s).strip()
    if s.startswith("{") and s.endswith("}"):
        s = s[1:-1]
    return s.lower() if s else ""


def _collect_essential_tab_ids(session):
    """Collect set of tab IDs (or indices) that the session marks as essential."""
    out = set()
    # Top-level
    for key in ("essentialTabIds", "essentialTabs", "pinnedEssentialIds"):
        val = session.get(key)
        if isinstance(val, list):
            for x in val:
                out.add(str(x))
        elif isinstance(val, dict):
            out.update(str(k) for k in val)
    # Nested under zen / browser
    for node in (session.get("zen"), session.get("browser"), session.get("storage")):
        if isinstance(node, dict):
            for key in ("essentialTabIds", "essentialTabs", "pinnedEssentialIds"):
                val = node.get(key)
                if isinstance(val, list):
                    for x in val:
                        out.add(str(x))
    # Per-window
    for w in session.get("windows", []):
        for key in ("essentialTabIds", "essentialTabs", "pinnedEssentialIds"):
            val = w.get(key)
            if isinstance(val, list):
                for x in val:
                    out.add(str(x))
    return out


def _tab_is_essential(t, essential_ids=None):
    """True if the tab object or session marks this tab as essential."""
    # Zen browser: zenEssential is the authoritative flag (string "true" / "false")
    zen_essential = t.get("zenEssential")
    if zen_essential is not None:
        if isinstance(zen_essential, str) and zen_essential.strip().lower() == "true":
            return True
        if isinstance(zen_essential, bool) and zen_essential:
            return True
        # Explicit "false" or falsy → not essential
        if isinstance(zen_essential, str) and zen_essential.strip().lower() == "false":
            return False
        if isinstance(zen_essential, bool) and not zen_essential:
            return False
    # Fallback: other explicit keys on tab
    for key in ("isEssential", "essential", "essentialTab", "isEssentialTab", "pinnedAsEssential"):
        val = t.get(key)
        if val is None:
            continue
        if isinstance(val, bool):
            if val:
                return True
        elif isinstance(val, str):
            if val.lower() in ("true", "1", "yes"):
                return True
        else:
            if val:
                return True
    # Nested: attributes.essential, customData.essential
    for node_key in ("attributes", "customData", "storage", "state"):
        node = t.get(node_key)
        if isinstance(node, dict) and node.get("essential"):
            return True
    # Any key containing "essential" with truthy value
    for k, v in t.items():
        if "essential" in k.lower() and v:
            if isinstance(v, bool) or (isinstance(v, str) and v.lower() in ("true", "1", "yes")):
                return True
    # Session-level set of essential tab IDs
    if essential_ids:
        tid = _tab_id(t)
        if tid and tid in essential_ids:
            return True
        # Index-based (some formats store position: 0..n-1 for essential)
        idx = t.get("index")
        if idx is not None and str(idx) in essential_ids:
            return True
    return False


def nix_escape(s):
    return s.replace("\\", "\\\\").replace('"', '\\"')


def slug(title, url):
    """Stable short name for a pin (for Nix attr name)."""
    if title and re.match(r"^[\w\s\-]+$", title[:30]):
        return re.sub(r"\s+", " ", title).strip()[:40]
    # derive from domain or path
    if url:
        from urllib.parse import urlparse
        try:
            p = urlparse(url)
            host = (p.netloc or p.path or "tab").split(".")[-2] if p.netloc else "tab"
            return host.capitalize()
        except Exception:
            pass
    return "Tab"


def _read_mozlz4(path):
    with open(path, "rb") as f:
        data = f.read()
    if data[:8] != b"mozLz40\x00":
        return None
    return json.loads(lz4.block.decompress(data[8:]).decode("utf-8"))


def _collect_spaces(session):
    """Collect space id -> {name, icon?, position?} from session (top-level or windows)."""
    spaces = {}
    _UUID_RE = re.compile(r"^[0-9a-f\-]{36}$", re.I)

    def add_space(sid, name, icon="", position=None):
        if sid:
            sid = _normalize_zen_workspace(sid) or str(sid).strip()
            if not sid:
                return
            existing = spaces.get(sid, {})
            existing_name = (existing.get("name") or "").strip()
            new_name = (name or "").strip()
            new_icon = (icon or "").strip()
            # Prefer new name if we don't have one, or if existing is "Default" and new is not (sidebar/zen wins over window)
            should_set = (
                sid not in spaces
                or (new_name and (not existing_name or existing_name == "Default"))
            )
            if should_set:
                spaces[sid] = {
                    "name": new_name or existing_name or "Default",
                    "icon": new_icon or existing.get("icon") or "",
                    "position": position if position is not None else existing.get("position"),
                }

    def deep_collect_space_objects(obj, path=""):
        """Walk session recursively; any dict with id/uuid (UUID) + name/spaceName/title is a space."""
        if isinstance(obj, dict):
            sid = _normalize_zen_workspace(obj.get("id") or obj.get("uuid") or obj.get("spaceId") or "")
            if sid and _UUID_RE.match(sid):
                name = obj.get("name") or obj.get("spaceName") or obj.get("title") or ""
                if name and isinstance(name, str):
                    add_space(sid, name.strip(), obj.get("icon") or "", obj.get("position"))
            for k, v in obj.items():
                deep_collect_space_objects(v, path + "." + str(k))
        elif isinstance(obj, list):
            for i, v in enumerate(obj):
                deep_collect_space_objects(v, path + "[%d]" % i)

    # Deep walk first so we pick up spaces from any nested structure (e.g. extension state)
    deep_collect_space_objects(session)

    # Top-level spaces: zen-sessions.jsonlz4 root IS the sidebar (ZenSessionManager saves #sidebar = { spaces, tabs, ... })
    # So session.spaces is the canonical list with uuid, name, icon, position. Prefer uuid (Zen's field name).
    for key in ("spaces", "workspaces", "spaceList", "zenSpaces"):
        arr = session.get(key)
        if isinstance(arr, list):
            for s in arr:
                if isinstance(s, dict):
                    sid = s.get("uuid") or s.get("id") or s.get("spaceId") or ""
                    add_space(sid, s.get("name") or s.get("spaceName") or s.get("title") or "", s.get("icon") or "", s.get("position"))
                elif isinstance(s, str):
                    add_space(s, s)
        elif isinstance(arr, dict):
            for sid, attrs in arr.items():
                if isinstance(attrs, dict):
                    add_space(str(sid), attrs.get("name") or attrs.get("spaceName") or str(sid), attrs.get("icon") or "", attrs.get("position"))
                else:
                    add_space(str(sid), str(attrs))
    # Zen: sidebar.spaces is the canonical list with name + icon (ZenSessionManager.sys.mjs).
    # Sidebar may be at top level or under session / global / browser.
    def _add_sidebar_spaces(sidebar_node):
        if not isinstance(sidebar_node, dict):
            return
        arr = sidebar_node.get("spaces")
        if isinstance(arr, list):
            for s in arr:
                if isinstance(s, dict):
                    sid = s.get("uuid") or s.get("id") or s.get("spaceId") or ""
                    add_space(
                        sid,
                        s.get("name") or s.get("spaceName") or s.get("title") or "",
                        s.get("icon") or "",
                        s.get("position"),
                    )
        elif isinstance(arr, dict):
            for sid, attrs in arr.items():
                if isinstance(attrs, dict):
                    add_space(
                        str(sid),
                        attrs.get("name") or attrs.get("spaceName") or str(sid),
                        attrs.get("icon") or "",
                        attrs.get("position"),
                    )

    _add_sidebar_spaces(session.get("sidebar"))
    for top in ("session", "global", "browser"):
        _add_sidebar_spaces((session.get(top) or {}).get("sidebar"))
    # Nested under "zen" or "browser" (Zen-specific)
    for top in ("zen", "browser", "storage"):
        node = session.get(top)
        if isinstance(node, dict):
            for key in ("spaces", "workspaces", "spaceList"):
                arr = node.get(key)
                if isinstance(arr, list):
                    for s in arr:
                        if isinstance(s, dict):
                            sid = s.get("id") or s.get("spaceId") or s.get("uuid") or ""
                            add_space(sid, s.get("name") or s.get("spaceName") or s.get("title") or "", s.get("icon") or "", s.get("position"))
                elif isinstance(arr, dict):
                    for sid, attrs in arr.items():
                        if isinstance(attrs, dict):
                            add_space(str(sid), attrs.get("name") or attrs.get("spaceName") or str(sid), attrs.get("icon") or "", attrs.get("position"))
    # From each window: Zen stores space list in window.spaces (uuid, name, icon, position)
    # and current workspace in workspaceID. See ZenSessionManager #restoreWindowData.
    for w in session.get("windows", []):
        for s in w.get("spaces") or []:
            if isinstance(s, dict):
                sid = s.get("uuid") or s.get("id") or s.get("spaceId") or ""
                add_space(
                    sid,
                    s.get("name") or s.get("spaceName") or s.get("title") or "",
                    s.get("icon") or "",
                    s.get("position"),
                )
        sid = w.get("workspaceID") or w.get("spaceId") or w.get("spaceID") or ""
        sid = _normalize_zen_workspace(sid) or sid
        if sid:
            add_space(sid, w.get("spaceName") or w.get("workspaceName") or "Default", w.get("spaceIcon") or "", w.get("spacePosition"))
    return spaces


def _tab_id(t):
    """Normalize tab id from tab object."""
    tid = t.get("id") or t.get("tabId") or t.get("linkedPanelId")
    return str(tid) if tid is not None else None


def _folder_map_from_window(w):
    """Build folder_id -> title from window.folders.

    Zen (zen-browser/desktop) stores folders as a list of metadata objects with:
    id, name, parentId, prevSiblingInfo, emptyTabIds, etc. No 'entries' array.
    Tabs reference the folder via groupId (same as folder id). See
    src/zen/folders/ZenFolders.mjs storeDataForSessionStore().
    """
    folder_map = {}
    folders = w.get("folders") if isinstance(w, dict) else {}
    if isinstance(folders, dict):
        for fid, attrs in folders.items():
            if isinstance(attrs, dict):
                name = attrs.get("name") or attrs.get("title") or attrs.get("label") or ""
            else:
                name = str(attrs) if attrs else ""
            if fid:
                folder_map[str(fid)] = (name or "Folder").strip()
    elif isinstance(folders, list):
        for f in folders:
            if not isinstance(f, dict):
                continue
            # Zen: id and name from storeDataForSessionStore()
            fid = f.get("id") or f.get("folderId") or f.get("linkedPanelId") or f.get("tabId")
            if not fid:
                continue
            fid = str(fid)
            name = f.get("name") or f.get("title") or f.get("label") or "Folder"
            folder_map[fid] = (name if isinstance(name, str) else "Folder").strip()
    return folder_map


def _is_folder_tab(t):
    """True if this tab object represents a folder (nested or flat list)."""
    if t.get("isFolder") or t.get("isFolderGroup"):
        return True
    if t.get("type") == "folder" or t.get("tabType") == "folder":
        return True
    # Flat list: folder has childTabIds / childTabs and typically no real URL
    if t.get("childTabIds") or (t.get("childTabs") and not (t.get("entries") or [{}])[0].get("url")):
        return True
    return False


def _folder_title_from_tab(t):
    """Extract folder title from a folder tab."""
    title = t.get("folderTitle") or t.get("title") or t.get("label") or t.get("name") or ""
    if isinstance(title, str):
        title = title.strip() or None
    return title or "Folder"


def _build_folder_map_and_tabs(tabs, folder_title=None):
    """Walk tab tree; return (folder_id_to_title: dict, flat_pinned_tabs: list with folder_title attached)."""
    folder_map = {}
    pinned_flat = []

    def walk(items, parent_folder_title=None, parent_folder_id=None):
        for t in items or []:
            tid = _tab_id(t)
            if _is_folder_tab(t):
                sub = t.get("children") or t.get("childTabs") or t.get("tabs") or []
                title = _folder_title_from_tab(t)
                if tid:
                    folder_map[tid] = title or "Folder"
                walk(sub, parent_folder_title=title, parent_folder_id=tid)
                continue
            if t.get("pinned"):
                entries = t.get("entries") or [{}]
                ent = entries[0] if entries else {}
                raw_url = ent.get("url")
                url = _normalize_url(raw_url)
                if not isinstance(url, str):
                    url = (url[-1] if isinstance(url, list) and url else None) or None
                url = str(url).strip() if url else None
                if not _should_skip_url(url):
                    pin_folder = parent_folder_title or t.get("folderTitle") or t.get("folder")
                    pinned_flat.append((t, url, ent, pin_folder))
            # Recurse into children even for non-folder (some formats nest)
            sub = t.get("children") or t.get("childTabs") or t.get("tabs") or []
            if sub:
                walk(sub, parent_folder_title=parent_folder_title, parent_folder_id=parent_folder_id)

    walk(tabs, parent_folder_title=folder_title)
    return folder_map, pinned_flat


def _tab_pins_from_tabs(
    tabs,
    folder_title=None,
    folder_map=None,
    essential_ids=None,
    window_workspace="",
    window_folder_map=None,
):
    """Yield pin dicts; resolve parentTabId/parent/openingTabId/zenFolderId to folder from folder_map."""
    folder_map_in, pinned_flat = _build_folder_map_and_tabs(tabs, folder_title=folder_title)
    folder_map = folder_map or folder_map_in
    if window_folder_map:
        folder_map = {**folder_map, **window_folder_map}
    for t, url, ent, pin_folder in pinned_flat:
        title = ent.get("title") or ""
        if isinstance(title, str):
            title = title.strip() or None
        else:
            title = None
        is_essential = _tab_is_essential(t, essential_ids)
        tab_id = _tab_id(t)
        # Resolve folder: Zen stores folders in window.folders (id, name, parentId); tabs
        # reference the folder via groupId (folder id = tab group id). See zen-browser/desktop
        # src/zen/folders/ZenFolders.mjs storeDataForSessionStore() and SessionManager.
        parent_id = (
            t.get("groupId")
            or t.get("zenFolderId")
            or t.get("folderId")
            or t.get("parentTabId")
            or t.get("parent")
            or t.get("openingTabId")
        )
        if parent_id is not None:
            parent_id = str(parent_id)
            if parent_id in folder_map and pin_folder is None:
                pin_folder = folder_map[parent_id]
        # Space: Zen stores per-tab zenWorkspace; fallback to window workspace
        space_id = _normalize_zen_workspace(t.get("zenWorkspace") or window_workspace)
        pin = {
            "title": title,
            "url": url,
            "isEssential": bool(is_essential),
            "folder": pin_folder if pin_folder else None,
            "tabId": tab_id,
            "spaceId": space_id,
        }
        yield pin


def _load_session():
    """Load first available session from SESSION_PATHS. Used by all Zen session scripts."""
    for path in SESSION_PATHS:
        if os.path.isfile(path):
            s = _read_mozlz4(path)
            if s is not None:
                return s
    return None


def load_pinned_per_space(session=None):
    if session is None:
        session = _load_session()
    if session is None:
        print(
            f"Session file not found or invalid. Tried:\n  {ZEN_SESSIONS_FILE}\n  {SESSIONSTORE_MAIN}\n  {SESSIONSTORE_RECOVERY}",
            file=sys.stderr,
        )
        sys.exit(2)

    spaces_map = _collect_spaces(session)

    def _merge_space(sid, name, icon, position):
        if not sid:
            return
        sid = _normalize_zen_workspace(sid) or str(sid).strip()
        if not sid:
            return
        existing = spaces_map.get(sid) or {"name": "Default", "icon": "", "position": None}
        # Prefer other session's name/icon when non-empty (zen-sessions has canonical names/icons)
        new_name = (name or "").strip() or existing.get("name") or "Default"
        new_icon = (icon or "").strip() if (icon or "").strip() else (existing.get("icon") or "")
        new_pos = position if position is not None else existing.get("position")
        spaces_map[sid] = {"name": new_name, "icon": new_icon, "position": new_pos}

    def _merge_spaces_from_session(other_session):
        if not other_session:
            return
        # zen-sessions.jsonlz4 root IS the sidebar ({ spaces, tabs, ... }), so top-level "spaces" has name/icon
        for s in other_session.get("spaces") or []:
            if isinstance(s, dict):
                sid = s.get("uuid") or s.get("id") or s.get("spaceId") or ""
                _merge_space(sid, s.get("name") or s.get("spaceName") or s.get("title"), s.get("icon"), s.get("position"))
        # Also check nested sidebar (e.g. if session format ever wraps sidebar)
        def _merge_sidebar(sidebar_node):
            if not isinstance(sidebar_node, dict):
                return
            for s in (sidebar_node.get("spaces") or []):
                if isinstance(s, dict):
                    sid = s.get("uuid") or s.get("id") or s.get("spaceId") or ""
                    _merge_space(sid, s.get("name") or s.get("spaceName") or s.get("title"), s.get("icon"), s.get("position"))
        _merge_sidebar(other_session.get("sidebar"))
        for top in ("session", "global", "browser"):
            _merge_sidebar((other_session.get(top) or {}).get("sidebar"))
        for w in other_session.get("windows") or []:
            for s in w.get("spaces") or []:
                if isinstance(s, dict):
                    sid = s.get("uuid") or s.get("id") or s.get("spaceId") or ""
                    _merge_space(sid, s.get("name") or s.get("spaceName") or s.get("title"), s.get("icon"), s.get("position"))

    # Enrich from Zen session files (spaces with names live in zen-sessions*, not in Firefox recovery)
    zen_session_paths = [ZEN_SESSIONS_FILE]
    if os.path.isdir(ZEN_SESSIONS_BACKUP_DIR):
        clean = os.path.join(ZEN_SESSIONS_BACKUP_DIR, "clean.jsonlz4")
        if os.path.isfile(clean):
            zen_session_paths.append(clean)
        try:
            files = sorted(
                (f for f in os.listdir(ZEN_SESSIONS_BACKUP_DIR) if f.startswith("zen-sessions-") and f.endswith(".jsonlz4")),
                reverse=True,
            )
            for f in files[:1]:  # latest backup only
                zen_session_paths.append(os.path.join(ZEN_SESSIONS_BACKUP_DIR, f))
        except OSError:
            pass
    for path in zen_session_paths + [os.path.join(ZEN_PROFILE_ROOT, "sessionstore-backups", "previous.jsonlz4")]:
        if os.path.isfile(path):
            other = _read_mozlz4(path)
            _merge_spaces_from_session(other)

    # Optional: merge space names from a JSON file (when session has no names, e.g. recovery-only)
    if os.path.isfile(ZEN_SPACE_NAMES_FILE):
        try:
            with open(ZEN_SPACE_NAMES_FILE, encoding="utf-8") as f:
                custom = json.load(f)
            if isinstance(custom, dict):
                for sid_raw, val in custom.items():
                    sid = _normalize_zen_workspace(str(sid_raw)) or str(sid_raw).strip()
                    if not sid:
                        continue
                    if isinstance(val, dict):
                        name = val.get("name") or val.get("spaceName") or ""
                        icon = val.get("icon") or ""
                        position = val.get("position")
                    else:
                        name = str(val).strip() if val else ""
                        icon = ""
                        position = None
                    if name:
                        spaces_map[sid] = {**(spaces_map.get(sid) or {"name": "Default", "icon": "", "position": None}), "name": name, "icon": icon or spaces_map.get(sid, {}).get("icon") or "", "position": position if position is not None else spaces_map.get(sid, {}).get("position")}
        except (OSError, json.JSONDecodeError):
            pass
    essential_ids = _collect_essential_tab_ids(session)
    windows = session.get("windows", [])

    # Collect all pins from all windows; each pin has spaceId (from zenWorkspace or window workspaceID)
    space_pins = {}  # space_id -> list of pins
    for w in windows:
        window_workspace = _normalize_zen_workspace(
            w.get("workspaceID") or w.get("spaceId") or w.get("spaceID") or ""
        )
        window_folder_map = _folder_map_from_window(w)
        win_essential = set(essential_ids)
        for key in ("essentialTabIds", "essentialTabs", "pinnedEssentialIds"):
            val = w.get(key)
            if isinstance(val, list):
                win_essential.update(str(x) for x in val)
        for pin in _tab_pins_from_tabs(
            w.get("tabs", []),
            essential_ids=win_essential,
            window_workspace=window_workspace,
            window_folder_map=window_folder_map,
        ):
            sid = pin.get("spaceId") or window_workspace or "default"
            if sid not in space_pins:
                space_pins[sid] = []
            space_pins[sid].append(pin)

        # Zen folders are metadata only (id, name, parentId); tab->folder is via tab.groupId.
        # No need to iterate folder.entries — Zen does not store entries on folders.

    # Ensure every space that has pins has an entry (may come only from tab.zenWorkspace)
    for space_id in space_pins:
        if space_id and space_id not in spaces_map:
            spaces_map[space_id] = {"name": "Default", "icon": "", "position": None}

    spaces_list = [
        {"id": sid, "name": attrs.get("name") or "Default", "icon": attrs.get("icon") or "", "position": attrs.get("position")}
        for sid, attrs in sorted(spaces_map.items(), key=lambda x: (x[1].get("position") or 0, x[0]))
    ]

    out_windows = []
    default_name_count = 0
    for space_id, pins in sorted(space_pins.items(), key=lambda x: (x[0],)):
        space_name = (spaces_map.get(space_id) or {}).get("name") or "Default"
        if space_name == "Default":
            default_name_count += 1
        out_windows.append({
            "spaceId": space_id,
            "spaceName": space_name,
            "pins": pins,
        })
    if default_name_count > 0 and not os.path.isfile(ZEN_SPACE_NAMES_FILE):
        print(
            f"Tip: {default_name_count} space(s) show as 'Default'. Add {ZEN_SPACE_NAMES_FILE} (spaceId -> name) to set names.",
            file=sys.stderr,
        )

    return {"spaces": spaces_list, "windows": out_windows}


def _dump_tab_sample(session, file=None):
    """Print keys/structure of first few tabs to inspect session format (folder, essential)."""
    file = file or sys.stderr
    essential_ids = _collect_essential_tab_ids(session)
    print("Session essential IDs (top-level/window):", essential_ids or "(none)", file=file)
    for i, w in enumerate(session.get("windows", [])[:2]):
        tabs = w.get("tabs", [])
        print(f"Window {i}: {len(tabs)} tabs", file=file)
        for j, t in enumerate(tabs[:6]):
            keys = sorted(t.keys())
            essential_any = [k for k in keys if "essential" in k.lower()]
            print(f"  Tab {j} keys: {keys}" + (f"  [essential-related: {essential_any}]" if essential_any else ""), file=file)
            for k in ("pinned", "zenEssential", "zenWorkspace", "groupId", "zenFolderId", "isEssential", "essential", "folderTitle", "folder", "parentTabId", "parent", "openingTabId", "folderId", "isFolder", "childTabs", "children", "id", "tabId", "linkedPanelId"):
                if k in t:
                    v = t[k]
                    if k in ("entries", "children", "childTabs") and isinstance(v, list):
                        print(f"    {k}: [len={len(v)}]", file=file)
                    else:
                        print(f"    {k}: {v!r}", file=file)
            if t.get("pinned"):
                print(f"    -> _tab_is_essential: {_tab_is_essential(t, essential_ids)}", file=file)
        if len(tabs) > 6:
            print(f"  ... and {len(tabs) - 6} more tabs", file=file)


def main(args=None):
    ap = argparse.ArgumentParser(description="Extract Zen pinned tabs per workspace")
    ap.add_argument("--nix", action="store_true", help="Print Nix pins snippet for caya.nix")
    ap.add_argument("--dump-tab-sample", action="store_true", help="Print tab keys/structure to stderr to debug folder/essential")
    args = ap.parse_args(args)

    session = _load_session()
    if session is None:
        print(
            f"Session file not found or invalid. Tried:\n  {ZEN_SESSIONS_FILE}\n  {SESSIONSTORE_MAIN}\n  {SESSIONSTORE_RECOVERY}",
            file=sys.stderr,
        )
        sys.exit(2)
    if args.dump_tab_sample:
        _dump_tab_sample(session)
        if not args.nix:
            return

    out = load_pinned_per_space(session=session)
    spaces_list = out["spaces"]
    windows = out["windows"]

    if args.nix:
        # Emit spaces then pins (format matches caya.nix: name -> { id, icon, position })
        lines = []
        # spaces = { "Name" = { id = "..."; icon = "..."; position = N; }; ... } (name as key, like caya.nix)
        if spaces_list:
            lines.append("  spaces = {")
            used_names = set()
            for i, s in enumerate(spaces_list):
                name = s.get("name") or "Default"
                sid = s.get("id") or ""
                icon = s.get("icon") or ""
                pos = s.get("position")
                if pos is None or (isinstance(pos, (int, float)) and pos == 0):
                    pos = 1000 + i
                nix_key = nix_escape(name)
                if nix_key in used_names:
                    nix_key = nix_escape(f"{name} ({sid[:8]})")
                used_names.add(nix_key)
                lines.append(f'    "{nix_key}" = {{')
                lines.append(f'      id = "{sid}";')
                lines.append(f'      icon = "{nix_escape(icon)}";')
                lines.append(f'      position = {int(pos)};')
                lines.append("    };")
            lines.append("  };")
            lines.append("")
        # pins = { "Title" = { id = "..."; url = "..."; position = N; isEssential = true/false; }; ... }
        position = 101
        lines.extend([
            "  # Pinned tabs by workspace (from session store)",
            "  pins = {",
        ])
        seen_urls = set()
        used_keys = set()
        for group in windows:
            space_id = group.get("spaceId") or ""
            space_name = group.get("spaceName") or "Default"
            comment = f"--- {space_name}"
            if space_id:
                comment += f" (spaceId: {space_id})"
            lines.append(f'    # {comment}')
            for p in group["pins"]:
                url = p["url"]
                if url in seen_urls:
                    continue
                seen_urls.add(url)
                title = p.get("title") or slug(None, url)
                name = slug(title, url)
                key = name
                c = 0
                while key in used_keys:
                    c += 1
                    key = f"{name}_{c}"
                used_keys.add(key)
                pin_id = p.get("tabId")
                pin_id = str(pin_id) if pin_id is not None else str(uuid.uuid4()).lower()
                if not re.match(r"^[a-f0-9\-]{36}$", pin_id):
                    pin_id = str(uuid.uuid4()).lower()
                is_essential = p.get("isEssential", False)
                folder = p.get("folder")
                lines.append(f'    "{nix_escape(title or key)}" = {{')
                lines.append(f'      id = "{pin_id}";')
                lines.append(f'      url = "{nix_escape(url)}";')
                lines.append(f'      position = {position};')
                lines.append(f'      isEssential = {"true" if is_essential else "false"};')
                if folder:
                    lines.append(f'      # folder = "{nix_escape(folder)}";')
                lines.append("    };")
                position += 1
            lines.append("")
        lines.append("  };")
        print("\n".join(lines))
    else:
        print(json.dumps(out, indent=2))


if __name__ == "__main__":
    main()
