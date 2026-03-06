#!/usr/bin/env python3
"""
Update profiles/caya/spaces.nix, essentials.nix, and pins.nix from the live Zen session.
- Essentials = pins that appear in all workspaces (Zen "essential" tabs).
- Pins = per-workspace pins only (with spaceId for reference).
Creates dated backups (e.g. spaces.nix.2025-03-04T14-30-00.bak) before overwriting.

  uv run sync_caya_from_session.py
  ZEN_PROFILE_ROOT=~/path/to/zen/Profiles/default uv run sync_caya_from_session.py

Run from the scripts/ directory or with the repo root as cwd.
"""

import os
import re
import sys
import uuid
from datetime import datetime

_SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
# Zen app dir (parent of scripts/); profiles/caya lives here
_ZEN_DIR = os.path.dirname(_SCRIPT_DIR)
_CAYA_DIR = os.path.join(_ZEN_DIR, "profiles", "caya")

# Use extractor as library
sys.path.insert(0, _SCRIPT_DIR)
from extract_pinned_tabs import (
    _load_session,
    load_pinned_per_space,
    nix_escape,
    slug,
)


def _backup(path):
    if not os.path.isfile(path):
        return
    stamp = datetime.now().strftime("%Y-%m-%dT%H-%M-%S")
    backup_path = f"{path}.{stamp}.bak"
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()
    with open(backup_path, "w", encoding="utf-8") as f:
        f.write(content)
    print(f"Backed up to {os.path.basename(backup_path)}", file=sys.stderr)


def _write_spaces(spaces_list):
    """Build and write spaces.nix from list of {id, name, icon, position}.
    Names/icons from Zen session (zen-sessions.jsonlz4 root = sidebar.spaces)."""
    path = os.path.join(_CAYA_DIR, "spaces.nix")
    _backup(path)
    lines = []
    used_names = set()
    for i, s in enumerate(spaces_list):
        name = (s.get("name") or "").strip() or "Default"
        sid = s.get("id") or ""
        icon = s.get("icon")
        if icon is None:
            icon = ""
        icon = str(icon).strip()
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
        lines.append(f"      position = {int(pos)};")
        lines.append("    };")
    content = "\n".join(lines)
    wrapper = """# Zen workspaces (names/icons from zen-sessions.jsonlz4). Updated by sync_caya_from_session.py. Dated backups kept.
{ ... }: {
  spacesForce = true;
  spaces = {
"""
    wrapper += content + "\n" if content else ""
    wrapper += "  };\n}\n"
    with open(path, "w", encoding="utf-8") as f:
        f.write(wrapper)
    print(f"Wrote {path}", file=sys.stderr)


def _write_essentials_and_pins(windows):
    """
    Split pins into essentials (all-workspace) and pins (per-workspace).
    Write essentials.nix and pins.nix.
    """
    essentials_by_url = {}  # url -> { key, id, url, position }
    pins_list = []  # list of { key, id, url, position, spaceId }
    seen_urls_essential = set()
    seen_keys_essential = set()
    seen_keys_pins = set()
    pos_essential = 101
    pos_pin = 201

    for group in windows:
        space_id = group.get("spaceId") or ""
        space_name = group.get("spaceName") or "Default"
        for p in group["pins"]:
            url = p["url"]
            title = p.get("title") or slug(None, url)
            base_key = slug(title, url)
            is_essential = p.get("isEssential", False)
            if is_essential:
                seen = seen_keys_essential
            else:
                seen = seen_keys_pins
            key = base_key
            c = 0
            while key in seen:
                c += 1
                key = f"{base_key}_{c}"
            seen.add(key)
            pin_id = p.get("tabId")
            if pin_id is None:
                pin_id = str(uuid.uuid4()).lower()
            else:
                pin_id = str(pin_id)
            if not re.match(r"^[a-f0-9\-]{36}$", pin_id):
                pin_id = str(uuid.uuid4()).lower()

            if is_essential:
                if url not in seen_urls_essential:
                    seen_urls_essential.add(url)
                    essentials_by_url[url] = {
                        "key": nix_escape(title or key),
                        "id": pin_id,
                        "url": url,
                        "position": pos_essential,
                    }
                    pos_essential += 1
            else:
                pins_list.append(
                    {
                        "key": nix_escape(key),
                        "id": pin_id,
                        "url": url,
                        "position": pos_pin,
                        "spaceId": space_id,
                        "spaceName": space_name,
                    }
                )
                pos_pin += 1

    # Write essentials.nix
    path_ess = os.path.join(_CAYA_DIR, "essentials.nix")
    _backup(path_ess)
    lines = []
    for v in essentials_by_url.values():
        lines.append(f'    "{v["key"]}" = {{')
        lines.append(f'      id = "{v["id"]}";')
        lines.append(f'      url = "{nix_escape(v["url"])}";')
        lines.append(f"      position = {v['position']};")
        lines.append("    };")
    content_ess = "\n".join(lines)
    wrapper_ess = """# Essentials = pins in all workspaces. Updated by sync_caya_from_session.py.
{ ... }: {
  essentials = {
"""
    wrapper_ess += content_ess + "\n" if content_ess else ""
    wrapper_ess += "  };\n}\n"
    with open(path_ess, "w", encoding="utf-8") as f:
        f.write(wrapper_ess)
    print(f"Wrote {path_ess}", file=sys.stderr)

    # Write pins.nix (per-workspace)
    path_pins = os.path.join(_CAYA_DIR, "pins.nix")
    _backup(path_pins)
    lines = []
    for v in pins_list:
        lines.append(f"    # {v['spaceName']}")
        lines.append(f'    "{v["key"]}" = {{')
        lines.append(f'      id = "{v["id"]}";')
        lines.append(f'      url = "{nix_escape(v["url"])}";')
        lines.append(f"      position = {v['position']};")
        lines.append(f'      spaceId = "{v["spaceId"]}";')
        lines.append("    };")
    content_pins = "\n".join(lines)
    wrapper_pins = """# Per-workspace pins only. Updated by sync_caya_from_session.py. spaceId = which workspace.
{ ... }: {
  pins = {
"""
    wrapper_pins += content_pins + "\n" if content_pins else ""
    wrapper_pins += "  };\n}\n"
    with open(path_pins, "w", encoding="utf-8") as f:
        f.write(wrapper_pins)
    print(f"Wrote {path_pins}", file=sys.stderr)


def main():
    if not os.path.isdir(_CAYA_DIR):
        print(f"Error: caya profile dir not found: {_CAYA_DIR}", file=sys.stderr)
        sys.exit(1)
    session = _load_session()
    if session is None:
        print(
            "Error: no session file found. Tried zen-sessions, sessionstore, recovery.",
            file=sys.stderr,
        )
        sys.exit(2)
    out = load_pinned_per_space(session=session)
    spaces_list = out["spaces"]
    windows = out["windows"]
    if not spaces_list:
        print("Warning: no spaces in session", file=sys.stderr)
    if not windows:
        print("Warning: no windows/pins in session", file=sys.stderr)
    _write_spaces(spaces_list)
    _write_essentials_and_pins(windows)
    print("Done. base.nix is unchanged.", file=sys.stderr)


if __name__ == "__main__":
    main()
