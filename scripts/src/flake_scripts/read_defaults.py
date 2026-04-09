#!/usr/bin/env python3
"""
Read macOS defaults and convert to Nix format.
Usage:
  read-defaults [domain] [--only-changed] [--filter-system]

Options:
  --only-changed: Only show values that differ from system defaults (experimental)
  --filter-system: Filter out system-managed keys (timestamps, cache, etc.)

If no domain is provided, lists all domains.
"""

import json
import os
import re
import subprocess
import sys
from typing import Any, Optional


def run_command(cmd: list[str]) -> str:
    """Run a shell command and return output."""
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        return result.stdout.strip()
    except subprocess.CalledProcessError:
        return ""


def get_all_domains() -> list[str]:
    """Get all defaults domains."""
    output = run_command(["defaults", "domains"])
    if output:
        return [d.strip() for d in output.split(",") if d.strip()]
    return []


def parse_defaults_output(output: str) -> dict[str, Any]:
    """Parse defaults read output (simplified parser)."""
    result = {}
    lines = output.split("\n")
    for line in lines:
        line = line.strip()
        if not line or line.startswith("{"):
            continue

        if "=" in line:
            parts = line.split("=", 1)
            key = parts[0].strip().strip('"')
            value = parts[1].strip()
            result[key] = parse_value(value)

    return result


def parse_value(value: str) -> Any:
    """Parse a defaults value string."""
    value = value.strip().rstrip(";")

    # Boolean
    if value in ("1", "true", "YES"):
        return True
    if value in ("0", "false", "NO"):
        return False

    # Number
    try:
        if "." in value:
            return float(value)
        return int(value)
    except ValueError:
        pass

    # String (remove quotes)
    if value.startswith('"') and value.endswith('"'):
        return value[1:-1]

    return value


def to_nix_value(value: Any, indent: int = 2) -> str:
    """Convert a Python value to Nix format."""
    spaces = " " * indent

    if isinstance(value, bool):
        return "true" if value else "false"
    elif isinstance(value, (int, float)):
        return str(value)
    elif isinstance(value, str):
        escaped = value.replace("\\", "\\\\").replace('"', '\\"')
        return f'"{escaped}"'
    elif isinstance(value, dict):
        lines = ["{"]
        for k, v in value.items():
            nix_key = sanitize_key(k)
            nix_val = to_nix_value(v, indent + 2)
            lines.append(f"{spaces}  {nix_key} = {nix_val};")
        lines.append(f"{spaces}}}")
        return "\n".join(lines)
    elif isinstance(value, list):
        items = [to_nix_value(item, indent + 2) for item in value]
        return f"[ {' '.join(items)} ]"
    else:
        return f'"{str(value)}"'


def sanitize_key(key: str) -> str:
    """Sanitize a key for Nix (handle special characters)."""
    if re.search(r"[^a-zA-Z0-9_]", key):
        return f'"{key}"'
    return key


def is_system_key(key: str) -> bool:
    """Check if a key is system-managed (not user-configurable)."""
    system_patterns = [
        r"^SU",
        r"^NSStatusItem",
        r"LastCheck", r"LastUpdate", r"LastSync",
        r"Cache", r"CacheDate",
        r"InstallId", r"SessionId", r"UserId",
        r"Migrated", r"Migration",
        r"Version", r"PreferencesVersion",
        r"HasLaunched", r"HasRunBefore",
        r"TerminatedWith",
        r"MSAppCenter",
        r"DataSeparated",
        r"ViewSettings$",
        r"WindowLocation", r"ProgressWindow",
    ]
    for pattern in system_patterns:
        if re.search(pattern, key):
            return True
    return False


def get_default_value(domain: str, key: str) -> Optional[Any]:  # noqa: ARG001
    """Try to get the default value for a key (heuristic)."""
    defaults_map = {
        "AppleShowAllFiles": False,
        "FXPreferredViewStyle": "Nlsv",
        "ShowPathbar": False,
        "ShowStatusBar": False,
        "autohide": False,
        "showhidden": False,
        "location": "~/Desktop",
        "type": "png",
    }
    return defaults_map.get(key)


def read_defaults(domain: str, filter_system: bool = False) -> dict[str, Any] | None:
    """Read defaults for a domain and parse as plist."""
    try:
        plist_path = os.path.expanduser(f"~/Library/Preferences/{domain}.plist")
        if not os.path.exists(plist_path):
            return None

        result = subprocess.run(
            ["plutil", "-convert", "json", "-o", "-", plist_path],
            capture_output=True,
            text=True,
        )
        if result.returncode == 0 and result.stdout:
            prefs = json.loads(result.stdout)
            if filter_system:
                prefs = {k: v for k, v in prefs.items() if not is_system_key(k)}
            return prefs
    except Exception:
        pass

    try:
        result = subprocess.run(
            ["defaults", "read", domain],
            capture_output=True,
            text=True,
        )
        if result.returncode == 0:
            prefs = parse_defaults_output(result.stdout)
            if filter_system:
                prefs = {k: v for k, v in prefs.items() if not is_system_key(k)}
            return prefs
    except Exception:
        pass

    return None


def main():
    args = sys.argv[1:]
    filter_system = "--filter-system" in args
    only_changed = "--only-changed" in args
    args = [a for a in args if not a.startswith("--")]

    if args:
        domain = args[0]
        print(f"# Nix configuration for {domain}")
        if filter_system:
            print("# (System-managed keys filtered out)")
        if only_changed:
            print("# (Only showing values that differ from defaults)")
        print(f'targets.darwin.defaults."{domain}" = {{')

        prefs = read_defaults(domain, filter_system=filter_system)
        if prefs:
            shown_count = 0
            for key, value in sorted(prefs.items()):
                if only_changed:
                    default_val = get_default_value(domain, key)
                    if default_val is not None and value == default_val:
                        continue
                nix_key = sanitize_key(key)
                nix_value = to_nix_value(value)
                print(f"  {nix_key} = {nix_value};")
                shown_count += 1
            if only_changed and shown_count == 0:
                print("  # All values match defaults (or defaults unknown)")
        else:
            print("  # No preferences found or couldn't read domain")
        print("};")
    else:
        print("Available defaults domains:")
        domains = get_all_domains()
        for domain in sorted(domains):
            print(f"  {domain}")
        print("\nUsage: read-defaults <domain> [--filter-system] [--only-changed]")
        print("\nOptions:")
        print("  --filter-system  Filter out system-managed keys")
        print("  --only-changed   Only show values that differ from known defaults (experimental)")


if __name__ == "__main__":
    main()
