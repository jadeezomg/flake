#!/usr/bin/env python3
"""Update profiles/<name>/spaces.nix and pins.nix from the live Zen session. Dated backups kept.
Output profile: darwin -> caya, NixOS/Linux -> default (override with ZEN_OUTPUT_PROFILE)."""

import os
import re
import sys
import uuid
from datetime import datetime

_SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
_FLAKE_ROOT = os.path.dirname(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
)


def _output_profile_name():
    if "ZEN_OUTPUT_PROFILE" in os.environ:
        return os.environ["ZEN_OUTPUT_PROFILE"]
    return "caya" if sys.platform == "darwin" else "default"


_OUTPUT_PROFILE_DIR = os.path.join(
    _FLAKE_ROOT,
    "home",
    "shared",
    "apps",
    "browsers",
    "zen",
    "profiles",
    _output_profile_name(),
)
sys.path.insert(0, _SCRIPT_DIR)
from extract_pinned_tabs import load_pinned_per_space, nix_escape, slug


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
    path = os.path.join(_OUTPUT_PROFILE_DIR, "spaces.nix")
    _backup(path)
    used = set()
    lines = []
    for i, s in enumerate(spaces_list):
        name = (s.get("name") or "").strip() or "Default"
        sid = s.get("id") or ""
        icon = str(s.get("icon") or "").strip()
        pos = s.get("position")
        if pos is None or (isinstance(pos, (int, float)) and pos == 0):
            pos = 1000 + i
        key = nix_escape(name)
        if key in used:
            key = nix_escape(f"{name} ({sid[:8]})")
        used.add(key)
        lines.append(
            '    "'
            + key
            + '" = { id = "'
            + sid
            + '"; icon = "'
            + nix_escape(icon)
            + '"; position = '
            + str(int(pos))
            + "; };"
        )
    body = "\n".join(lines)
    with open(path, "w", encoding="utf-8") as f:
        f.write(
            "# Zen workspaces. Updated by sync_caya_from_session.py.\n{ ... }: {\n  spacesForce = true;\n  spaces = {\n"
            + body
            + "\n  };\n}\n"
        )
    print(f"Wrote {path}", file=sys.stderr)


def _space_id_to_nix_key(spaces_list):
    used = set()
    out = {}
    for s in spaces_list:
        name = (s.get("name") or "").strip() or "Default"
        sid = s.get("id") or ""
        key = nix_escape(name)
        if key in used:
            key = nix_escape(f"{name} ({sid[:8]})")
        used.add(key)
        out[sid] = key
    return out


def _write_pins(windows, folders, spaces_list):
    space_to_key = _space_id_to_nix_key(spaces_list)
    seen_urls_essential = set()
    seen_keys_all = set()
    pos_essential = 101
    pos_pin = 201
    entries = []

    for group in windows:
        for p in group["pins"]:
            if not p.get("isEssential"):
                continue
            url = p["url"]
            if url in seen_urls_essential:
                continue
            seen_urls_essential.add(url)
            title = p.get("title") or slug(None, url)
            key = nix_escape(title or slug(None, url))
            c = 0
            while key in seen_keys_all:
                c += 1
                key = nix_escape(f"{title or 'Essential'}_{c}")
            seen_keys_all.add(key)
            pin_id = p.get("tabId") or str(uuid.uuid4()).lower()
            if not re.match(r"^[a-f0-9\-]{36}$", str(pin_id)):
                pin_id = str(uuid.uuid4()).lower()
            frag = (
                '      id = "'
                + pin_id
                + '";\n      url = "'
                + nix_escape(url)
                + '";\n      isEssential = true;\n      position = '
                + str(pos_essential)
                + ";"
            )
            if p.get("containerId") is not None:
                frag += "\n      container = " + str(int(p["containerId"])) + ";"
            entries.append((key, frag))
            pos_essential += 1

    for f in folders:
        fid = f.get("id") or ""
        name = (f.get("name") or "").strip() or "Folder"
        space_id = f.get("spaceId") or ""
        nix_space = space_to_key.get(
            space_id, nix_escape(f.get("spaceName") or "Default")
        )
        key = nix_escape(name)
        c = 0
        while key in seen_keys_all:
            c += 1
            key = nix_escape(f"{name}_{c}")
        seen_keys_all.add(key)
        pos = f.get("position", 1000)
        parent_id = f.get("parentId")
        frag = (
            '      id = "'
            + fid
            + '";\n      workspace = spaces."'
            + nix_space
            + '".id;\n      isGroup = true;\n      isFolderCollapsed = true;\n      editedTitle = true;\n      position = '
            + str(pos)
            + ";"
        )
        if parent_id:
            frag += '\n      folderParentId = "' + parent_id + '";'
        entries.append((key, frag))

    for group in windows:
        space_id = group.get("spaceId") or ""
        space_name = group.get("spaceName") or "Default"
        nix_space = space_to_key.get(space_id, nix_escape(space_name))
        for p in group["pins"]:
            if p.get("isEssential"):
                continue
            url = p["url"]
            title = p.get("title") or slug(None, url)
            base_key = slug(title, url)
            key = nix_escape(base_key)
            c = 0
            while key in seen_keys_all:
                c += 1
                key = nix_escape(f"{base_key}_{c}")
            seen_keys_all.add(key)
            pin_id = p.get("tabId") or str(uuid.uuid4()).lower()
            if not re.match(r"^[a-f0-9\-]{36}$", str(pin_id)):
                pin_id = str(uuid.uuid4()).lower()
            folder_id = p.get("folderId")
            frag = (
                '      id = "'
                + pin_id
                + '";\n      url = "'
                + nix_escape(url)
                + '";\n      workspace = spaces."'
                + nix_space
                + '".id;\n      isEssential = false;\n      position = '
                + str(pos_pin)
                + ";"
            )
            if folder_id:
                frag += '\n      folderParentId = "' + folder_id + '";'
            if p.get("containerId") is not None:
                frag += "\n      container = " + str(int(p["containerId"])) + ";"
            pos_pin += 1
            entries.append((key, frag))

    path = os.path.join(_OUTPUT_PROFILE_DIR, "pins.nix")
    _backup(path)
    body = "\n".join('    "' + k + '" = {\n' + v + "\n    };" for k, v in entries)
    with open(path, "w", encoding="utf-8") as f:
        f.write(
            "# Pins and folders (skifli format). Updated by sync_caya_from_session.py.\n{ ... }: let\n  spaces = (import ./spaces.nix {}).spaces;\nin {\n  pinsForce = true;\n  pins = {\n"
            + body
            + "\n  };\n}\n"
        )
    print(f"Wrote {path}", file=sys.stderr)


def main():
    if not os.path.isdir(_OUTPUT_PROFILE_DIR):
        print(f"Error: profile dir not found: {_OUTPUT_PROFILE_DIR}", file=sys.stderr)
        sys.exit(1)
    out = load_pinned_per_space()
    spaces_list = out["spaces"]
    windows = out["windows"]
    folders = out.get("folders") or []
    if not spaces_list:
        print("Warning: no spaces in session", file=sys.stderr)
    if not windows:
        print("Warning: no windows/pins in session", file=sys.stderr)
    _write_spaces(spaces_list)
    _write_pins(windows, folders, spaces_list)
    print("Done.", file=sys.stderr)


if __name__ == "__main__":
    main()
