"""Update custom flake packages from per-package update.json metadata.

Custom handlers cover package sources `nix-update` cannot resolve directly:
npm registry tarballs, platform-agnostic release zips (`fetchzip`), and
prebuilt binary release channels.
"""

import base64
import hashlib
import json
import re
import shutil
import ssl
import subprocess
import sys
import threading
import time
import tarfile
import tempfile
import urllib.error
import urllib.parse
import urllib.request
from collections.abc import Callable
from typing import Any
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

import certifi
from rich.progress import (
    MofNCompleteColumn,
    Progress,
    SpinnerColumn,
    TaskID,
    TextColumn,
    TimeElapsedColumn,
)

from flake_scripts.lib.common import console, resolve_flake_root

_SSL = ssl.create_default_context(cafile=certifi.where())

# `nix-update --flake` evaluates the whole flake; parallel runs race on inputs/git.
_NIX_UPDATE_LOCK = threading.Lock()

# Skip registry/GitHub fetches if we checked this package recently (per-machine state).
COOLDOWN_DEFAULT_SEC = 3600
CHECK_STATE_FILENAME = ".update-check.json"

StatusCb = Callable[[str], None]


def _check_state_path(pkg_dir: Path) -> Path:
    return pkg_dir / CHECK_STATE_FILENAME


def _read_last_checked(pkg_dir: Path) -> float | None:
    path = _check_state_path(pkg_dir)
    try:
        t = json.loads(path.read_text(encoding="utf-8")).get("checked_at")
        return float(t) if isinstance(t, (int, float)) else None
    except (OSError, json.JSONDecodeError, TypeError):
        return None


def _write_last_checked(pkg_dir: Path) -> None:
    path = _check_state_path(pkg_dir)
    path.write_text(
        json.dumps({"checked_at": time.time()}, indent=2) + "\n",
        encoding="utf-8",
    )


def _cooldown_remaining_human(last: float, cooldown_s: int) -> str:
    left = max(0, int(cooldown_s - (time.time() - last)))
    if left >= 3600:
        return f"{left // 3600}h {(left % 3600) // 60}m left"
    if left >= 60:
        return f"{left // 60}m left"
    return f"{left}s left"


def _fetch_json(url: str) -> dict:
    req = urllib.request.Request(
        url,
        headers={
            "Accept": "application/json",
            "User-Agent": "flake-update-packages/1.0",
        },
    )
    with urllib.request.urlopen(req, timeout=15, context=_SSL) as r:
        return json.loads(r.read())


def _fetch_text(url: str) -> str:
    req = urllib.request.Request(
        url,
        headers={"Accept": "text/plain", "User-Agent": "flake-update-packages/1.0"},
    )
    with urllib.request.urlopen(req, timeout=15, context=_SSL) as r:
        return r.read().decode("utf-8").strip()


def _file_sri(path: Path) -> str:
    """SRI sha256 of a file (matches fetchurl without unpack)."""
    return subprocess.run(
        ["nix", "hash", "file", "--type", "sha256", "--sri", str(path)],
        capture_output=True,
        text=True,
        check=True,
    ).stdout.strip()


def _npm_deps_hash(lock_file: Path) -> str:
    return subprocess.run(
        ["nix", "run", "nixpkgs#prefetch-npm-deps", "--", str(lock_file)],
        capture_output=True,
        text=True,
        check=True,
    ).stdout.strip()


# npm handlers run in parallel; the first `nix run nixpkgs#...` per machine must
# resolve + unpack the nixpkgs flake into the Git cache. Concurrent cold-cache
# invocations race on that and fail. Warming the tool once serializes it.
_NPM_HANDLER_TYPES = {"npm"}


def _warm_prefetch_tool() -> None:
    """Build nixpkgs#prefetch-npm-deps once so parallel handlers hit a warm cache."""
    subprocess.run(
        ["nix", "build", "--no-link", "nixpkgs#prefetch-npm-deps"],
        capture_output=True,
        text=True,
        check=False,
    )


def _replace_attr_once(path: Path, field: str, value: str) -> None:
    """Set `field = "value"` on the first matching line (optional indent). Fails if not found."""
    text = path.read_text()
    pattern = rf'(?m)^([ \t]*{re.escape(field)}\s*=\s*)"[^"]*"'
    new_text, n = re.subn(pattern, rf'\1"{value}"', text, count=1)
    if n != 1:
        raise RuntimeError(
            f"{path}: expected exactly 1 line matching attribute {field!r}, got {n}. "
            "Check default.nix uses the same attribute name as update.json."
        )
    path.write_text(new_text)


def _has_attr(text: str, field: str) -> bool:
    return bool(re.search(rf"(?m)^[ \t]*{re.escape(field)}\s*=", text))


def _require_fields(pkg_name: str, meta: dict[str, Any], fields: list[str]) -> None:
    for field in fields:
        if field not in meta:
            raise ValueError(
                f"{pkg_name}: update.json missing required field {field!r}"
            )


def _require_text_field(pkg_name: str, meta: dict[str, Any], field: str) -> None:
    if not isinstance(meta.get(field), str) or not meta[field]:
        raise ValueError(
            f"{pkg_name}: update.json field {field!r} must be a non-empty string"
        )


def _require_default_attr(
    pkg_name: str, nix_text: str, source_field: str, attr_name: str
) -> None:
    if not _has_attr(nix_text, attr_name):
        raise ValueError(
            f"{pkg_name}: update.json field {source_field!r} references missing "
            f"default.nix attribute {attr_name!r}"
        )


def _binary_channel_platforms(
    meta: dict[str, Any],
) -> list[tuple[str | None, str, str]]:
    platforms = meta.get("platforms")
    if isinstance(platforms, dict):
        rows = []
        for nix_system, row in platforms.items():
            if not isinstance(row, dict):
                continue
            upstream = row.get("upstream_platform") or row.get("platform")
            field = row.get("hash_field")
            if isinstance(upstream, str) and isinstance(field, str):
                rows.append((str(nix_system), upstream, field))
        return rows

    hash_fields = meta.get("hash_fields")
    if isinstance(hash_fields, dict):
        return [
            (None, str(upstream_platform), str(field))
            for upstream_platform, field in hash_fields.items()
        ]
    return []


def validate_update_metadata(
    pkg_dir: Path, meta: dict[str, Any], nix_text: str
) -> None:
    pkg_name = pkg_dir.name
    handler_type = meta.get("type")
    valid_types = {"nix-update", *_HANDLERS.keys()}
    if not isinstance(handler_type, str) or handler_type not in valid_types:
        raise ValueError(
            f"{pkg_name}: update.json field 'type' has unsupported handler {handler_type!r}; "
            f"expected one of {', '.join(sorted(valid_types))}"
        )

    if handler_type == "nix-update":
        extra_args = meta.get("extra_args", [])
        if not isinstance(extra_args, list) or not all(
            isinstance(arg, str) for arg in extra_args
        ):
            raise ValueError(
                f"{pkg_name}: update.json field 'extra_args' must be a list of strings"
            )
        return

    if handler_type == "npm":
        _require_fields(
            pkg_name,
            meta,
            ["package", "hash_field", "npm_deps_hash_field", "lock_file"],
        )
        for field in ["package", "hash_field", "npm_deps_hash_field", "lock_file"]:
            _require_text_field(pkg_name, meta, field)
        _require_default_attr(pkg_name, nix_text, "hash_field", meta["hash_field"])
        _require_default_attr(
            pkg_name, nix_text, "npm_deps_hash_field", meta["npm_deps_hash_field"]
        )
        return

    if handler_type == "fetchzip":
        _require_fields(pkg_name, meta, ["version_url", "url_template"])
        for field in ["version_url", "url_template"]:
            _require_text_field(pkg_name, meta, field)
        if "{version}" not in meta["url_template"]:
            raise ValueError(
                f"{pkg_name}: update.json field 'url_template' must include {{version}}"
            )
        if "version_jsonpath" in meta:
            _require_text_field(pkg_name, meta, "version_jsonpath")
        if "version_strip_prefix" in meta and not isinstance(
            meta["version_strip_prefix"], str
        ):
            raise ValueError(
                f"{pkg_name}: update.json field 'version_strip_prefix' must be a string"
            )
        hash_field = meta.get("hash_field", "sha256")
        if not isinstance(hash_field, str) or not hash_field:
            raise ValueError(
                f"{pkg_name}: update.json field 'hash_field' must be a non-empty string"
            )
        _require_default_attr(pkg_name, nix_text, "hash_field", hash_field)
        return

    if handler_type == "binary_channel":
        _require_fields(pkg_name, meta, ["version_url", "url_template"])
        for field in ["version_url", "url_template"]:
            _require_text_field(pkg_name, meta, field)
        if (
            "{version}" not in meta["url_template"]
            or "{platform}" not in meta["url_template"]
        ):
            raise ValueError(
                f"{pkg_name}: update.json field 'url_template' must include {{version}} and {{platform}}"
            )
        if "version_jsonpath" in meta:
            _require_text_field(pkg_name, meta, "version_jsonpath")
        if "version_strip_prefix" in meta and not isinstance(
            meta["version_strip_prefix"], str
        ):
            raise ValueError(
                f"{pkg_name}: update.json field 'version_strip_prefix' must be a string"
            )

        has_new = "platforms" in meta
        has_legacy = "hash_fields" in meta
        if has_new == has_legacy:
            raise ValueError(
                f"{pkg_name}: update.json field 'platforms' is required; legacy 'hash_fields' remains supported alone"
            )

        platform_rows = _binary_channel_platforms(meta)
        if not platform_rows:
            field = "platforms" if has_new else "hash_fields"
            raise ValueError(
                f"{pkg_name}: update.json field {field!r} must not be empty"
            )

        if has_new:
            for nix_system, upstream_platform, hash_field in platform_rows:
                if not nix_system:
                    raise ValueError(
                        f"{pkg_name}: update.json field 'platforms' has empty Nix system"
                    )
                if nix_system not in nix_text:
                    raise ValueError(
                        f"{pkg_name}: update.json field 'platforms.{nix_system}' is missing from default.nix"
                    )
                if upstream_platform not in nix_text:
                    raise ValueError(
                        f"{pkg_name}: update.json field 'platforms.{nix_system}.upstream_platform' "
                        f"references {upstream_platform!r}, missing from default.nix"
                    )
                _require_default_attr(
                    pkg_name,
                    nix_text,
                    f"platforms.{nix_system}.hash_field",
                    hash_field,
                )
        else:
            for _, upstream_platform, hash_field in platform_rows:
                _require_default_attr(
                    pkg_name, nix_text, f"hash_fields.{upstream_platform}", hash_field
                )
        return


def _current_version(text: str) -> str:
    m = re.search(r'version\s*=\s*"([^"]+)"', text)
    return m.group(1) if m else "unknown"


def _npm_integrity_sha512_from_url(url: str) -> str:
    req = urllib.request.Request(url, headers={"Accept": "application/octet-stream"})
    with urllib.request.urlopen(req, timeout=60, context=_SSL) as r:
        data = r.read()
    digest = hashlib.sha512(data).digest()
    return "sha512-" + base64.b64encode(digest).decode()


def _patch_lock_missing_integrity(lock: dict) -> None:
    """Add integrity hashes for registry entries that npm-shrinkwrap omits.

    Some tarballs (e.g. @earendil-works/pi-coding-agent) ship a shrinkwrap whose
    own-scope entries lack `integrity`. prefetch-npm-deps panics on those.
    We compute sha512 integrity from the resolved tarball URL for each affected entry.
    """
    packages = lock.get("packages")
    if not isinstance(packages, dict):
        return
    for entry in packages.values():
        if not isinstance(entry, dict):
            continue
        if "integrity" in entry or entry.get("link"):
            continue
        resolved = entry.get("resolved", "")
        if not resolved.startswith("https://"):
            continue
        entry["integrity"] = _npm_integrity_sha512_from_url(resolved)


def _handle_npm(
    meta: dict, pkg_dir: Path, status: StatusCb, current_version: str
) -> tuple[str, dict]:
    status("fetching latest version from npm")
    data = _fetch_json(f"https://registry.npmjs.org/{meta['package']}/latest")
    new_version = data["version"]
    tarball_url = data["dist"]["tarball"]

    with tempfile.TemporaryDirectory() as tmp:
        tgz = Path(tmp) / "pkg.tgz"
        status("downloading tarball")
        with urllib.request.urlopen(tarball_url, timeout=30, context=_SSL) as r:
            tgz.write_bytes(r.read())
        status("hashing tarball")
        src_hash = _file_sri(tgz)
        with tarfile.open(tgz) as tf:
            tf.extractall(tmp)
        pkg_json = Path(tmp) / "package" / "package.json"
        # npm-shrinkwrap.json takes precedence over package-lock.json — if the
        # tarball ships one, `npm install --package-lock-only` updates the
        # shrinkwrap and never emits package-lock.json. Remove it so the lock
        # path below is guaranteed to exist.
        (pkg_json.parent / "npm-shrinkwrap.json").unlink(missing_ok=True)
        status("generating package-lock.json")
        proc = subprocess.run(
            ["npm", "install", "--package-lock-only", "--ignore-scripts"],
            cwd=pkg_json.parent,
            capture_output=True,
            text=True,
        )
        if proc.returncode != 0:
            raise RuntimeError(
                f"npm install --package-lock-only failed:\n{proc.stderr or proc.stdout}"
            )
        # Some packages ship npm-shrinkwrap.json; npm updates it in place instead
        # of creating package-lock.json. Accept either.
        lock_src = pkg_json.parent / "package-lock.json"
        if not lock_src.exists():
            lock_src = pkg_json.parent / "npm-shrinkwrap.json"
        if not lock_src.exists():
            raise RuntimeError(
                "npm install --package-lock-only produced neither package-lock.json "
                f"nor npm-shrinkwrap.json in {pkg_json.parent}"
            )
        lock = json.loads(lock_src.read_text())
        status("patching missing integrity hashes")
        _patch_lock_missing_integrity(lock)
        dest_lock = pkg_dir / meta["lock_file"]
        dest_lock.write_text(json.dumps(lock, indent=2) + "\n")
        status("hashing npm deps")
        deps_hash = _npm_deps_hash(dest_lock)

    return new_version, {
        # Keep fetchurl in sync with npm `dist.tarball` (version bumps alone miss this).
        "url": tarball_url,
        meta["hash_field"]: src_hash,
        meta["npm_deps_hash_field"]: deps_hash,
    }


def _prefetch_file_hash(url: str) -> str:
    with tempfile.TemporaryDirectory() as tmp:
        out = Path(tmp) / "download.bin"
        req = urllib.request.Request(
            url,
            headers={
                "Accept": "application/octet-stream",
                "User-Agent": "flake-update-packages/1.0",
            },
        )
        with urllib.request.urlopen(req, timeout=120, context=_SSL) as r:
            out.write_bytes(r.read())
        return _file_sri(out)


def _resolve_latest_version(meta: dict[str, Any]) -> str:
    if "version_jsonpath" in meta:
        data = _fetch_json(meta["version_url"])
        new_version: Any = data
        for segment in str(meta["version_jsonpath"]).split("."):
            new_version = new_version[segment]
        new_version = str(new_version)
    else:
        new_version = _fetch_text(meta["version_url"])

    prefix = meta.get("version_strip_prefix")
    if prefix and new_version.startswith(prefix):
        new_version = new_version[len(prefix) :]
    return new_version


def _prefetch_fetchzip_hash(url: str) -> str:
    proc = subprocess.run(
        ["nix", "store", "prefetch-file", "--unpack", "--json", url],
        capture_output=True,
        text=True,
        check=True,
    )
    return json.loads(proc.stdout)["hash"]


def _handle_fetchzip(
    meta: dict, pkg_dir: Path, status: StatusCb, current_version: str
) -> tuple[str, dict]:
    status("fetching latest version")
    new_version = _resolve_latest_version(meta)
    if new_version == current_version:
        return new_version, {}

    hash_field = meta.get("hash_field", "sha256")
    url = meta["url_template"].format(version=new_version)
    status("prefetching release zip")
    return new_version, {hash_field: _prefetch_fetchzip_hash(url)}


def _handle_binary_channel(
    meta: dict, pkg_dir: Path, status: StatusCb, current_version: str
) -> tuple[str, dict]:
    """Generic binary updater with version endpoint and URL template.

    Short-circuits on matching versions so no-op runs do not re-download large
    release assets just to rediscover unchanged hashes.
    """
    status("fetching latest version")
    new_version = _resolve_latest_version(meta)
    if new_version == current_version:
        return new_version, {}

    field_updates = {}
    for _, platform, field in _binary_channel_platforms(meta):
        status(f"prefetching {platform}")
        url = meta["url_template"].format(version=new_version, platform=platform)
        field_updates[field] = _prefetch_file_hash(url)

    return new_version, field_updates


_HANDLERS = {
    "binary_channel": _handle_binary_channel,
    "fetchzip": _handle_fetchzip,
    "npm": _handle_npm,
}


def _nix_update_cmd(flake_root: Path, args: list[str]) -> list[str]:
    """Build a `nix-update` invocation, falling back to `nix develop` when nix-update
    is not on PATH (e.g. when update-packages is invoked outside the flake devShell)."""
    if shutil.which("nix-update"):
        return ["nix-update", *args]
    return ["nix", "develop", str(flake_root), "--command", "nix-update", *args]


def _handle_nix_update_self(
    meta: dict,
    pkg_dir: Path,
    status: StatusCb,
    old_version: str,
    nix_text_before: str,
) -> tuple[str, str, bool, bool]:
    """Self-applying handler: `nix-update` rewrites default.nix in place.

    Returns (old_version, new_version, version_changed, fields_changed).
    """
    attr = meta.get("attr", pkg_dir.name)
    extra = list(meta.get("extra_args") or [])
    flake_root = pkg_dir.parent.parent

    status("running nix-update")
    cmd = _nix_update_cmd(flake_root, ["--flake", *extra, attr])
    with _NIX_UPDATE_LOCK:
        proc = subprocess.run(
            cmd,
            cwd=flake_root,
            capture_output=True,
            text=True,
        )
        if proc.returncode != 0:
            msg = proc.stderr.strip() or proc.stdout.strip() or "nix-update failed"
            raise RuntimeError(msg)

    nix_text_after = (pkg_dir / "default.nix").read_text()
    new_version = _current_version(nix_text_after)
    version_changed = new_version != old_version
    fields_changed = (not version_changed) and (nix_text_after != nix_text_before)
    return old_version, new_version, version_changed, fields_changed


def _field_updates_changed(nix_text: str, field_updates: dict[str, str]) -> bool:
    return any(
        not re.search(
            rf'(?m)^[ \t]*{re.escape(field)}\s*=\s*"{re.escape(value)}"',
            nix_text,
        )
        for field, value in field_updates.items()
    )


def _apply_update_rewrites(
    nix_file: Path,
    *,
    version_changed: bool,
    new_version: str,
    field_updates: dict[str, str],
) -> None:
    if version_changed:
        _replace_attr_once(nix_file, "version", new_version)
    for field, value in field_updates.items():
        _replace_attr_once(nix_file, field, value)


def _cooldown_skip(pkg_dir: Path, cooldown_s: int) -> tuple[bool, str | None]:
    if cooldown_s <= 0:
        return False, None
    last = _read_last_checked(pkg_dir)
    if last is not None and (time.time() - last) < cooldown_s:
        return True, _cooldown_remaining_human(last, cooldown_s)
    return False, None


def update_package(
    pkg_dir: Path,
    status: StatusCb,
    *,
    force: bool = False,
    cooldown_s: int = COOLDOWN_DEFAULT_SEC,
) -> tuple[str, str, bool, bool, bool]:
    """Update a single package.

    Returns (old_version, new_version, version_changed, fields_changed, cooldown_skipped).
    cooldown_skipped is True when no network work ran due to the per-package cooldown.
    fields_changed is True when hashes drifted even without a version bump.
    """
    nix_file = pkg_dir / "default.nix"
    nix_text = nix_file.read_text()
    old_version = _current_version(nix_text)

    meta = json.loads((pkg_dir / "update.json").read_text())
    validate_update_metadata(pkg_dir, meta, nix_text)

    if not force:
        cooldown_skipped, remaining = _cooldown_skip(pkg_dir, cooldown_s)
        if cooldown_skipped:
            status(f"skipped (cooldown {remaining})")
            return old_version, old_version, False, False, True

    if meta["type"] == "nix-update":
        old, new, v_changed, f_changed = _handle_nix_update_self(
            meta, pkg_dir, status, old_version, nix_text
        )
        _write_last_checked(pkg_dir)
        return old, new, v_changed, f_changed, False

    handler = _HANDLERS[meta["type"]]
    new_version, field_updates = handler(meta, pkg_dir, status, old_version)

    version_changed = new_version != old_version
    fields_changed = _field_updates_changed(nix_text, field_updates)

    if not version_changed and not fields_changed:
        _write_last_checked(pkg_dir)
        return old_version, new_version, False, False, False

    status("writing updated default.nix")
    _apply_update_rewrites(
        nix_file,
        version_changed=version_changed,
        new_version=new_version,
        field_updates=field_updates,
    )

    _write_last_checked(pkg_dir)
    return old_version, new_version, version_changed, fields_changed, False


def discover_packages(flake_root: Path) -> list[Path]:
    return sorted(p.parent for p in (flake_root / "packages").glob("*/update.json"))


def main(args: list[str] | None = None) -> None:
    import argparse

    flake_root = resolve_flake_root()
    all_pkgs = discover_packages(flake_root)
    all_names = [p.name for p in all_pkgs]

    ap = argparse.ArgumentParser(description="Update custom flake packages")
    ap.add_argument(
        "--force",
        action="store_true",
        help="Ignore the 1h per-package cooldown and re-fetch from registries/APIs.",
    )
    ap.add_argument(
        "packages",
        nargs="*",
        choices=all_names,
        metavar="PACKAGE",
        help=f"Packages to update (default: all). Available: {', '.join(all_names)}",
    )
    parsed = ap.parse_args(args)

    targets = (
        [flake_root / "packages" / n for n in parsed.packages]
        if parsed.packages
        else all_pkgs
    )

    changed: list[str] = []
    failed = False

    # Warm the npm prefetch tool before fanning out so concurrent cold-cache
    # `nix run nixpkgs#prefetch-npm-deps` calls don't race on flake resolution.
    if any(
        json.loads((p / "update.json").read_text()).get("type") in _NPM_HANDLER_TYPES
        for p in targets
    ):
        console.print("[dim]warming nixpkgs#prefetch-npm-deps…[/]")
        _warm_prefetch_tool()

    with Progress(
        SpinnerColumn(finished_text=" "),
        TextColumn("{task.fields[icon]}"),
        TextColumn("{task.description:<20}"),
        TextColumn("{task.fields[step]}"),
        MofNCompleteColumn(),
        TimeElapsedColumn(),
        console=console,
        transient=False,
    ) as progress:
        overall = progress.add_task("total", total=len(targets), step="", icon=" ")
        pkg_tasks: dict[Path, TaskID] = {}
        for pkg_dir in targets:
            tid = progress.add_task(pkg_dir.name, total=1, step="queued", icon=" ")
            pkg_tasks[pkg_dir] = tid

        def make_status(tid: TaskID) -> StatusCb:
            def _cb(msg: str) -> None:
                progress.update(tid, step=msg)

            return _cb

        def finish(
            tid: TaskID, icon: str, name_style: str, name: str, step: str
        ) -> None:
            progress.update(
                tid,
                icon=icon,
                description=f"[{name_style}]{name}[/]",
                step=step,
                completed=1,
            )

        with ThreadPoolExecutor(max_workers=len(targets)) as executor:
            futures = {
                executor.submit(
                    update_package,
                    pkg_dir,
                    make_status(pkg_tasks[pkg_dir]),
                    force=parsed.force,
                ): pkg_dir
                for pkg_dir in targets
            }
            for future in as_completed(futures):
                pkg_dir = futures[future]
                tid = pkg_tasks[pkg_dir]
                name = pkg_dir.name
                try:
                    old, new, version_changed, fields_changed, cooldown_skipped = (
                        future.result()
                    )
                    if cooldown_skipped:
                        finish(tid, "[dim]~[/]", "dim", name, "[dim]cooldown (1h)[/]")
                    elif version_changed:
                        finish(
                            tid, "[green]✓[/]", "bold", name, f"{old} → [green]{new}[/]"
                        )
                        changed.append(name)
                    elif fields_changed:
                        finish(
                            tid,
                            "[yellow]✓[/]",
                            "bold",
                            name,
                            f"[yellow]hashes updated[/] ({new})",
                        )
                        changed.append(name)
                    else:
                        finish(
                            tid, "[dim]–[/]", "dim", name, f"[dim]already at {new}[/]"
                        )
                except Exception as e:
                    msg = str(e)
                    last = next(
                        (ln for ln in reversed(msg.splitlines()) if ln.strip()), msg
                    )
                    progress.console.print(f"[red]{name}[/]: {msg}")
                    finish(tid, "[red]✗[/]", "red", name, f"[red]{last}[/]")
                    failed = True
                finally:
                    progress.advance(overall)

        progress.update(overall, step="")

    if changed:
        console.print(
            f"[bold]Updated {len(changed)} package(s).[/] Run [cyan]just fmt && just switch[/] to apply."
        )
    elif not failed:
        console.print("[dim]All packages up to date.[/]")

    if failed:
        sys.exit(1)


if __name__ == "__main__":
    main()
