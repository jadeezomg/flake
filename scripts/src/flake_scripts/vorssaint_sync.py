#!/usr/bin/env python3
"""Sync live Vorssaint settings into the flake (brew-casks/data/vorssaint.nix)."""

from __future__ import annotations

import argparse
import difflib
import plistlib
import re
import subprocess
import sys
from datetime import datetime
from pathlib import Path

from flake_scripts.lib.common import bad, info, resolve_flake_root, warn

_FLAKE_ROOT = resolve_flake_root(anchor=Path(__file__))
_DATA_FILE = (
    _FLAKE_ROOT
    / "modules"
    / "profiles"
    / "work"
    / "darwin"
    / "brew-casks"
    / "data"
    / "vorssaint.nix"
)
_DOMAIN = "com.vorssaint.utils"
_FEATURE_PREFIX = "featureAvailable."
_SYNC_TOOL = "vorssaint-sync"

# Keys that hold app state, not settings. The list mirrors
# SettingsBackupSupport.machineStateKeys and the onboarding flags in the
# Vorssaint source: its own settings export leaves these keys out too.
_STATE_KEYS = frozenset(
    {
        # Onboarding, feature intros and update intros.
        "brightnessUpdatePromptState",
        "featureHubKeptFeatures",
        "featuresOnboardingVersion",
        "hasOnboarded",
        "lastUpdateIntroVersion",
        "onboardingStep",
        "panelCollapsedResetVersion",
        "supportUpdateIntroVersion",
        "updateHighlightsSeenVersion",
        # One-time markers and content that are not in machineStateKeys.
        "notchDefaultProfileInitialized",
        "shelfItems",
        # SettingsBackupSupport.machineStateKeys
        "appUpdatesLastCheck",
        "appUpdatesLastCount",
        "appUpdatesNotifiedIDs",
        "bluetoothSleepRestorePending",
        "brightnessDDCWriteOnlyPaths",
        "brightnessDDCWriteOnlyPathsRechecked",
        "brightnessExtendedDimmingPaths",
        "brightnessForcedSoftwarePaths",
        "cleanerLastAutoFailed",
        "cleanerLastAutoFreed",
        "cleanerLastAutoRun",
        "clipboardHistoryWindowHeight",
        "clipboardHistoryWindowWidth",
        "commandBarFileScopes",
        "commandBarQueryHabitKey",
        "commandBarQueryHabits",
        "commandBarUsage",
        "displaysSwitchedOff",
        "displaysSwitchedOffFingerprints",
        "dockPreviewRestoreAutohide",
        "fanControlHelperVersion",
        "fanControlRecoveryNeeded",
        "fanControlResumeConfiguration",
        "mediaImageWatermarkLogoPath",
        "micMuteActive",
        "micMuteMutedDevices",
        "micMuteSavedChannelVolumes",
        "micMuteSavedVolume",
        "micMuteSavedVolumes",
        "musicBlockReplacementPath",
        "notchAgentsCodexProfiles",
        "notchAgentsOptInMigrated",
        "notchCameraFitHeight",
        "notchCameraFitWidth",
        "notchDownloadsFolderBookmark",
        "orphanedCaptureShortcutMigrated",
        "recorderSaveFolder",
        "recorderSystemAudioTapVerified",
        "restoredScreenCaptureShortcutsMigrated",
        "screenshotLoupeLastZoom",
        "screenshotSaveFolder",
        "screenshotSharingDeveloperEndpoint",
        "settingsWindowHeight",
        "settingsWindowWidth",
        "simulateUpdate",
        "spacesOrderRestartPending",
        "spacesOrderRestore",
        "switcherNativeHotkeysSuppressed",
        "systemShortcutsSuppressed",
        "unifiedScreenCaptureShortcutMigrated",
        "updateShowcaseIntroVersion",
        "updateShowcaseMediaOverride",
        "wallpaperExcludedOwnPaths",
        "wallpaperOwnBookmarks",
        "whatsAppDownloadsAccessConfirmed",
        "whatsAppDownloadsAutomaticStartDate",
        "whatsAppDownloadsExclusions",
        "whatsAppDownloadsLastAutoRun",
        "whatsAppDownloadsLastCleanup",
        "whatsAppDownloadsLastCleanupAutomatic",
        "whatsAppDownloadsLastCleanupBytes",
        "whatsAppDownloadsLastCleanupCount",
        "whatsAppDownloadsLastCleanupFailed",
        "whatsAppOrganizerDestinationPath",
        "whatsAppOrganizerLastDuplicates",
        "whatsAppOrganizerLastFailed",
        "whatsAppOrganizerLastMoved",
        "whatsAppOrganizerLastRun",
        "whatsAppOrganizerRecords",
        "whatsAppOrganizerUndoTransaction",
    }
)
# AppKit (NSStatusItem, NSWindow frames) and Sparkle write these prefixes.
_STATE_PREFIXES = ("NS", "SU", "com.apple.")

_NIX_KEYWORDS = frozenset(
    {"assert", "else", "if", "in", "inherit", "let", "or", "rec", "then", "with"}
)
_NIX_IDENT = re.compile(r"[A-Za-z_][A-Za-z0-9_'-]*")


def _is_state(key: str) -> bool:
    return key in _STATE_KEYS or key.startswith(_STATE_PREFIXES)


def _nix_expressible(value) -> bool:
    """False for data and date values: targets.darwin.defaults cannot write them."""
    if isinstance(value, (bytes, datetime)):
        return False
    if isinstance(value, list):
        return all(_nix_expressible(v) for v in value)
    if isinstance(value, dict):
        return all(_nix_expressible(v) for v in value.values())
    return True


def _nix_string(text: str) -> str:
    for old, new in (
        ("\\", "\\\\"),
        ('"', '\\"'),
        ("${", "\\${"),
        ("\n", "\\n"),
        ("\r", "\\r"),
        ("\t", "\\t"),
    ):
        text = text.replace(old, new)
    return f'"{text}"'


def _nix_name(key: str) -> str:
    if _NIX_IDENT.fullmatch(key) and key not in _NIX_KEYWORDS:
        return key
    return _nix_string(key)


def _nix_float(value: float) -> str:
    # Six decimals: lib.generators.toPlist writes floats with toString, which
    # keeps six, so a longer value would not survive a switch anyway.
    text = f"{value:.6f}".rstrip("0")
    return text + "0" if text.endswith(".") else text


def _nix_value(value) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int):
        return f"({value})" if value < 0 else str(value)
    if isinstance(value, float):
        text = _nix_float(value)
        return f"({text})" if value < 0 else text
    if isinstance(value, str):
        return _nix_string(value)
    if isinstance(value, list):
        return "[ " + " ".join(_nix_value(v) for v in value) + " ]"
    if isinstance(value, dict):
        return "{ " + _attrset_body(value) + " }"
    raise TypeError(f"unsupported value type: {type(value).__name__}")


def _attrset_body(attrs: dict) -> str:
    return " ".join(f"{_nix_name(k)} = {_nix_value(v)};" for k, v in attrs.items())


def split_domain(domain: dict) -> tuple[dict, dict, list[str]]:
    """Sort the domain into features, settings, and skipped data/date keys."""
    features: dict = {}
    settings: dict = {}
    skipped: list[str] = []
    for key in sorted(domain):
        value = domain[key]
        if _is_state(key):
            continue
        if not _nix_expressible(value):
            skipped.append(key)
        elif key.startswith(_FEATURE_PREFIX):
            features[key.removeprefix(_FEATURE_PREFIX)] = value
        else:
            settings[key] = value
    return features, settings, skipped


def render(features: dict, settings: dict) -> str:
    return (
        f"# Generated by `just {_SYNC_TOOL}` from the live {_DOMAIN}\n"
        "# defaults domain. Do not edit: change the setting in Vorssaint, then run\n"
        "# the sync. `features` are the Features hub switches (featureAvailable.*).\n"
        f"{{\n  features = {{ {_attrset_body(features)} }};\n"
        f"  settings = {{ {_attrset_body(settings)} }};\n}}\n"
    )


def _nix_fmt(content: str) -> str:
    if not content:
        return content
    proc = subprocess.run(
        ["nixfmt", "-"], input=content, text=True, capture_output=True, check=False
    )
    if proc.returncode != 0:
        msg = proc.stderr.strip() or f"exit {proc.returncode}"
        raise RuntimeError(f"nixfmt failed: {msg}")
    return proc.stdout


def _read_live_domain() -> dict:
    proc = subprocess.run(
        ["defaults", "export", _DOMAIN, "-"], capture_output=True, check=False
    )
    if proc.returncode != 0:
        msg = proc.stderr.decode(errors="replace").strip() or f"exit {proc.returncode}"
        raise RuntimeError(f"cannot read the {_DOMAIN} defaults domain: {msg}")
    return plistlib.loads(proc.stdout)


def sync(domain: dict, *, check: bool = False, quiet: bool = False) -> int:
    features, settings, skipped = split_domain(domain)
    for key in skipped:
        warn(f"skipped {key}: data and date values cannot go in Nix", stderr=True)
    expected = _nix_fmt(render(features, settings))
    actual = _DATA_FILE.read_text(encoding="utf-8") if _DATA_FILE.is_file() else ""
    if actual == expected:
        if not quiet:
            info("Flake Vorssaint settings match the live app.", stderr=True)
        return 0
    if not quiet:
        name = _DATA_FILE.name
        for line in difflib.unified_diff(
            actual.splitlines(keepends=True),
            expected.splitlines(keepends=True),
            fromfile=name,
            tofile=f"{name} (live)",
        ):
            print(line, end="", file=sys.stderr)
    if check:
        bad("Flake Vorssaint settings do not match the live app.", stderr=True)
        return 1
    _DATA_FILE.parent.mkdir(parents=True, exist_ok=True)
    _DATA_FILE.write_text(expected, encoding="utf-8")
    if not quiet:
        info(f"Wrote {_DATA_FILE}", stderr=True)
    return 0


def main(argv=None):
    ap = argparse.ArgumentParser(
        prog=_SYNC_TOOL,
        description=f"Sync live Vorssaint settings into {_DATA_FILE.name}",
    )
    ap.add_argument("--check", action="store_true", help="Compare only; no writes")
    ap.add_argument(
        "--input",
        metavar="PLIST",
        help=f"Read this plist file instead of the live {_DOMAIN} domain",
    )
    ap.add_argument(
        "--quiet", "-q", action="store_true", help="Suppress non-error output"
    )
    args = ap.parse_args(argv)
    try:
        if args.input:
            domain = plistlib.loads(Path(args.input).expanduser().read_bytes())
        elif sys.platform != "darwin":
            bad(
                "Vorssaint runs on macOS only; use --input on other hosts.", stderr=True
            )
            return 1
        else:
            domain = _read_live_domain()
        return sync(domain, check=args.check, quiet=args.quiet)
    except (OSError, RuntimeError, plistlib.InvalidFileException) as exc:
        bad(str(exc), stderr=True)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
