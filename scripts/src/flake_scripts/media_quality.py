"""Apply the media stack's efficient-4K download policy on mini."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import tempfile
import urllib.request
from pathlib import Path
from typing import Any

HOST = "mini"
PROFILE_ID = 7
PROFILE_NAME = "Efficient 4K"
MANAGED_FORMATS = {
    "Efficient 4K: Original Language": 10_000,
    "Efficient 4K: AV1": 600,
    "Efficient 4K: HEVC": 400,
    "Efficient 4K: WEB-DL": 200,
    "Efficient 4K: WEBRip": 150,
    "Efficient 4K: English Subtitles": 50,
}


class Arr:
    def __init__(self, name: str, port: int) -> None:
        self.name = name
        self.base = f"http://127.0.0.1:{port}/api/v3"
        self.key = Path(f"/run/secrets/mini/media/{name}/api-key").read_text().strip()

    def request(self, method: str, path: str, payload: Any | None = None) -> Any:
        data = None if payload is None else json.dumps(payload).encode()
        request = urllib.request.Request(
            f"{self.base}/{path}",
            data=data,
            method=method,
            headers={"Content-Type": "application/json", "X-Api-Key": self.key},
        )
        with urllib.request.urlopen(request, timeout=60) as response:
            body = response.read()
        return json.loads(body) if body else None

    def get(self, path: str) -> Any:
        return self.request("GET", path)

    def put(self, path: str, payload: Any) -> Any:
        return self.request("PUT", path, payload)

    def post(self, path: str, payload: Any) -> Any:
        return self.request("POST", path, payload)


def _specification(
    schemas: list[dict[str, Any]],
    implementation: str,
    name: str,
    values: dict[str, Any],
) -> dict[str, Any]:
    specification = next(item.copy() for item in schemas if item["implementation"] == implementation)
    specification["name"] = name
    specification["negate"] = False
    specification["required"] = False
    specification["fields"] = [field.copy() for field in specification["fields"]]
    for field in specification["fields"]:
        if field["name"] in values:
            field["value"] = values[field["name"]]
    return specification


def _format_payloads(arr: Arr) -> dict[str, dict[str, Any]]:
    schemas = arr.get("customformat/schema")
    source_values = {"sonarr": (3, 4), "radarr": (7, 8)}[arr.name]
    formats = {
        "Efficient 4K: Original Language": [
            _specification(
                schemas,
                "LanguageSpecification",
                "Original audio language",
                {"value": -2, "exceptLanguage": False},
            )
        ],
        "Efficient 4K: AV1": [
            _specification(
                schemas,
                "ReleaseTitleSpecification",
                "AV1 codec",
                {"value": r"\b(?:AV1|AV01)\b"},
            )
        ],
        "Efficient 4K: HEVC": [
            _specification(
                schemas,
                "ReleaseTitleSpecification",
                "HEVC codec",
                {"value": r"\b(?:x265|h[ ._-]?265|HEVC)\b"},
            )
        ],
        "Efficient 4K: WEB-DL": [
            _specification(
                schemas,
                "SourceSpecification",
                "WEB-DL source",
                {"value": source_values[0]},
            )
        ],
        "Efficient 4K: WEBRip": [
            _specification(
                schemas,
                "SourceSpecification",
                "WEBRip source",
                {"value": source_values[1]},
            )
        ],
        "Efficient 4K: English Subtitles": [
            _specification(
                schemas,
                "ReleaseTitleSpecification",
                "English subtitles in release name",
                {"value": r"\b(?:ENG(?:LISH)?[ ._-]?(?:SUBS?|SUBTITLES?)|SUBS?[ ._-]?ENG)\b"},
            )
        ],
    }
    return {
        name: {
            "name": name,
            "includeCustomFormatWhenRenaming": False,
            "specifications": specifications,
        }
        for name, specifications in formats.items()
    }


def _upsert_formats(arr: Arr) -> dict[str, int]:
    existing = {item["name"]: item for item in arr.get("customformat")}
    for name, payload in _format_payloads(arr).items():
        if name in existing:
            payload["id"] = existing[name]["id"]
            arr.put(f"customformat/{existing[name]['id']}", payload)
        else:
            arr.post("customformat", payload)
    return {item["name"]: item["id"] for item in arr.get("customformat")}


def _set_allowed(item: dict[str, Any], allowed: set[int]) -> bool:
    item_id = item.get("id") or item.get("quality", {}).get("id")
    children = item.get("items", [])
    if children:
        child_allowed = [_set_allowed(child, allowed) for child in children]
        item["allowed"] = item_id in allowed or any(child_allowed)
        if item_id in allowed:
            for child in children:
                child["allowed"] = True
        return item["allowed"]
    item["allowed"] = item_id in allowed
    return item["allowed"]


def _configure_profile(arr: Arr, format_ids: dict[str, int]) -> None:
    profile = arr.get(f"qualityprofile/{PROFILE_ID}")
    profile["name"] = PROFILE_NAME
    profile["upgradeAllowed"] = True
    profile["cutoff"] = 1003  # WEB 2160p
    profile["minFormatScore"] = 10_000  # Original language is mandatory.
    profile["cutoffFormatScore"] = 10_400  # Stop once HEVC or better is found.
    for item in profile["items"]:
        _set_allowed(item, {7, 9, 16, 19, 1002, 1003})

    managed_ids = set(format_ids.values())
    format_items = [item for item in profile.get("formatItems", []) if item["format"] not in managed_ids]
    format_items.extend(
        {"format": format_ids[name], "name": name, "score": score}
        for name, score in MANAGED_FORMATS.items()
    )
    profile["formatItems"] = format_items
    arr.put(f"qualityprofile/{PROFILE_ID}", profile)


def _configure_sizes(arr: Arr) -> None:
    limits = {
        "sonarr": {1080: (8.0, 40.0, 70.0), 2160: (20.0, 60.0, 100.0)},
        # MB/min: a 120-minute 4K movie prefers ~10 GiB and caps near 15 GiB.
        "radarr": {1080: (10.0, 45.0, 80.0), 2160: (25.0, 85.0, 128.0)},
    }[arr.name]
    for definition in arr.get("qualitydefinition"):
        quality = definition["quality"]
        name = quality["name"]
        resolution = quality["resolution"]
        if resolution not in limits or "Remux" in name or name in {"Raw-HD", "BR-DISK"}:
            continue
        minimum, preferred, maximum = limits[resolution]
        definition["minSize"] = minimum
        definition["preferredSize"] = preferred
        definition["maxSize"] = maximum
        arr.put(f"qualitydefinition/{definition['id']}", definition)


def _assign_profile(arr: Arr) -> int:
    entity, editor_key = ("series", "seriesIds") if arr.name == "sonarr" else ("movie", "movieIds")
    items = arr.get(entity)
    ids = [item["id"] for item in items if item.get("qualityProfileId") != PROFILE_ID]
    if ids:
        arr.put(f"{entity}/editor", {editor_key: ids, "qualityProfileId": PROFILE_ID})
    return len(ids)


def _configure_seerr() -> None:
    path = Path("/var/lib/private/seerr/settings.json")
    stat = path.stat()
    subprocess.run(["systemctl", "stop", "seerr"], check=True)
    try:
        settings = json.loads(path.read_text())
        for service in ("sonarr", "radarr"):
            for server in settings[service]:
                server["activeProfileId"] = PROFILE_ID
                server["activeProfileName"] = PROFILE_NAME
        with tempfile.NamedTemporaryFile("w", dir=path.parent, delete=False) as handle:
            json.dump(settings, handle, indent=2)
            handle.write("\n")
            os.fchmod(handle.fileno(), stat.st_mode)
            os.fchown(handle.fileno(), stat.st_uid, stat.st_gid)
            replacement = Path(handle.name)
        os.replace(replacement, path)
    finally:
        subprocess.run(["systemctl", "start", "seerr"], check=True)


def _verify(arr: Arr) -> None:
    profile = arr.get(f"qualityprofile/{PROFILE_ID}")
    formats = {item["name"]: item["score"] for item in profile["formatItems"]}
    assert profile["name"] == PROFILE_NAME
    assert profile["cutoff"] == 1003
    assert profile["minFormatScore"] == 10_000
    assert profile["cutoffFormatScore"] == 10_400
    assert all(formats[name] == score for name, score in MANAGED_FORMATS.items())


def _on_host(apply: bool) -> None:
    sonarr = Arr("sonarr", 8989)
    radarr = Arr("radarr", 7878)
    if not apply:
        print("Would configure Sonarr and Radarr profile 7 as Efficient 4K")
        print("Would require original-language audio and prefer AV1 > HEVC > AVC")
        print("Would target WEB 2160p; Radarr prefers ~10 GiB and caps ~15 GiB per 120 min")
        print("Would assign all existing series and movies and update Seerr defaults")
        return

    for arr in (sonarr, radarr):
        format_ids = _upsert_formats(arr)
        _configure_profile(arr, format_ids)
        _configure_sizes(arr)
        changed = _assign_profile(arr)
        _verify(arr)
        print(f"{arr.name}: applied {PROFILE_NAME}; reassigned {changed} items")
    _configure_seerr()
    print("seerr: selected Efficient 4K for Sonarr and Radarr")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true", help="apply changes (default: dry run)")
    parser.add_argument("--on-host", action="store_true", help=argparse.SUPPRESS)
    args = parser.parse_args()

    if args.on_host:
        _on_host(args.apply)
        return

    source = Path(__file__).read_text()
    command = ["ssh", HOST, "sudo", "python3", "-", "--on-host"]
    if args.apply:
        command.append("--apply")
    subprocess.run(command, input=source, text=True, check=True)


if __name__ == "__main__":
    main()
