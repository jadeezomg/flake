#!/usr/bin/env python3
"""
Read macOS defaults and convert to Nix format.
Usage: 
  python3 read-defaults.py [domain] [--only-changed] [--filter-system]
  
Options:
  --only-changed: Only show values that differ from system defaults (experimental)
  --filter-system: Filter out system-managed keys (timestamps, cache, etc.)
  
If no domain is provided, lists all domains.
"""

import subprocess
import sys
import json
import re
import os
import tempfile
from typing import Any, Optional

def run_command(cmd: list[str]) -> str:
    """Run a shell command and return output."""
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        return ""


def get_all_domains() -> list[str]:
    """Get all defaults domains."""
    output = run_command(["defaults", "domains"])
    if output:
        return [d.strip() for d in output.split(",") if d.strip()]
    return []


def parse_defaults_output(output: str) -> dict[str, Any]:
    """Parse defaults read output (simplified parser)."""
    # This is a basic parser - may need improvements
    result = {}
    lines = output.split("\n")
    current_key = None
    current_value = None
    
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
    value = value.strip().rstrip(';')
    
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
        # Escape special characters
        escaped = value.replace('\\', '\\\\').replace('"', '\\"')
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
    # If key contains special chars, wrap in quotes
    if re.search(r'[^a-zA-Z0-9_]', key):
        return f'"{key}"'
    return key


def is_system_key(key: str) -> bool:
    """Check if a key is system-managed (not user-configurable)."""
    system_patterns = [
        r'^SU',  # Sparkle update keys
        r'^NSStatusItem',  # Status bar item positions (can be user-set but often auto)
        r'LastCheck', r'LastUpdate', r'LastSync',  # Timestamps
        r'Cache', r'CacheDate',  # Cache values
        r'InstallId', r'SessionId', r'UserId',  # App identifiers
        r'Migrated', r'Migration',  # Migration flags
        r'Version', r'PreferencesVersion',  # Version numbers
        r'HasLaunched', r'HasRunBefore',  # First launch flags (can be useful)
        r'TerminatedWith',  # Crash/termination state
        r'MSAppCenter',  # Analytics/telemetry
        r'DataSeparated',  # Internal data
        r'ViewSettings$',  # Complex view state (usually auto-managed)
        r'WindowLocation', r'ProgressWindow',  # Window positions (usually auto)
    ]
    
    for pattern in system_patterns:
        if re.search(pattern, key):
            return True
    return False


def get_default_value(domain: str, key: str) -> Optional[Any]:
    """
    Try to get the default value for a key.
    This is tricky - we can't easily reset without losing data.
    Returns None if we can't determine the default.
    """
    # For now, we'll use heuristics based on common defaults
    # This is not perfect but helps identify likely user changes
    
    # Common default values
    defaults_map = {
        # Finder
        'AppleShowAllFiles': False,
        'FXPreferredViewStyle': 'Nlsv',  # List view
        'ShowPathbar': False,
        'ShowStatusBar': False,
        # Dock
        'autohide': False,
        'showhidden': False,
        # Screenshot
        'location': '~/Desktop',
        'type': 'png',
    }
    
    return defaults_map.get(key)


def read_defaults(domain: str, filter_system: bool = False) -> dict[str, Any] | None:
    """Read defaults for a domain and parse as plist."""
    try:
        # Use plutil to convert to JSON for easier parsing
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
            
            # Filter out system keys if requested
            if filter_system:
                prefs = {k: v for k, v in prefs.items() if not is_system_key(k)}
            
            return prefs
    except Exception:
        pass
    
    # Fallback: try defaults read
    try:
        result = subprocess.run(
            ["defaults", "read", domain],
            capture_output=True,
            text=True,
        )
        if result.returncode == 0:
            # Parse the output manually (simplified)
            prefs = parse_defaults_output(result.stdout)
            
            # Filter out system keys if requested
            if filter_system:
                prefs = {k: v for k, v in prefs.items() if not is_system_key(k)}
            
            return prefs
    except Exception:
        pass
    
    return None


def main():
    args = sys.argv[1:]
    filter_system = '--filter-system' in args
    only_changed = '--only-changed' in args
    
    # Remove flags from args
    args = [a for a in args if not a.startswith('--')]
    
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
                # If only_changed, check if value differs from default
                if only_changed:
                    default_val = get_default_value(domain, key)
                    if default_val is not None and value == default_val:
                        continue  # Skip if same as default
                
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
        print("\nUsage: python3 read-defaults.py <domain> [--filter-system] [--only-changed]")
        print("\nOptions:")
        print("  --filter-system  Filter out system-managed keys (timestamps, cache, etc.)")
        print("  --only-changed   Only show values that differ from known defaults (experimental)")


if __name__ == "__main__":
    main()

