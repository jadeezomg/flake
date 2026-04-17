"""Update custom flake packages by reading update.json metadata from each package dir.

Handler `type` values:
  - npm: registry.npmjs.org package (see packages/context7/update.json). Updates
    `version`, `url`, tarball `hash`, vendored `lock_file`, and `npmDepsHash`.
  - github_release: release asset URL + nix-prefetch-url (see iosevka packages).
  - github_tag: latest GitHub release tag (or newest tag if no releases), `nix-prefetch-github`
    for fetchFromGitHub `hash` (see packages/workato-platform-cli/update.json).
  - github_npm: latest GitHub release tag (or newest tag if no releases), `nix-prefetch-github`
    for fetchFromGitHub `hash`, vendored `lock_file` from the tag archive, `prefetch-npm-deps`
    for `npmDepsHash`, and `rev_field` set to the tag name. Optional `patch_git_ssh_lock`
    rewrites `git+ssh://git@github.com/...` lockfile entries to https tarball + integrity.

Each package stores `packages/<name>/.update-check.json` with `checked_at` (unix time).
By default a 1h cooldown skips re-fetching if that file is newer than the cooldown (use
`--force` to always fetch).
"""

import base64
import hashlib
import json
import re
import ssl
import subprocess
import sys
import time
import tarfile
import tempfile
import urllib.error
import urllib.parse
import urllib.request
from collections.abc import Callable
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

# Skip registry/GitHub fetches if we checked this package recently (per-machine state).
COOLDOWN_DEFAULT_SEC = 3600
CHECK_STATE_FILENAME = ".update-check.json"

StatusCb = Callable[[str], None]


def _noop(_: str) -> None: ...


def _check_state_path(pkg_dir: Path) -> Path:
    return pkg_dir / CHECK_STATE_FILENAME


def _read_last_checked(pkg_dir: Path) -> float | None:
    path = _check_state_path(pkg_dir)
    if not path.is_file():
        return None
    try:
        data = json.loads(path.read_text())
        t = data.get("checked_at")
        if isinstance(t, (int, float)):
            return float(t)
    except (json.JSONDecodeError, OSError, TypeError):
        return None
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
    req = urllib.request.Request(url, headers={"Accept": "application/json"})
    with urllib.request.urlopen(req, timeout=15, context=_SSL) as r:
        return json.loads(r.read())


def _nix_sri(url: str, *, unpack: bool = False) -> str:
    cmd = ["nix-prefetch-url", "--type", "sha256"]
    if unpack:
        cmd.append("--unpack")
    cmd.append(url)
    raw = subprocess.run(cmd, capture_output=True, text=True, check=True).stdout.strip()
    return subprocess.run(
        ["nix", "hash", "convert", "--hash-algo", "sha256", "--to", "sri", raw],
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


def _replace_attr_once(path: Path, field: str, value: str) -> None:
    """Set `field = \"value\"` on the first matching line (optional indent). Fails if not found."""
    text = path.read_text()
    pattern = rf'(?m)^([ \t]*{re.escape(field)}\s*=\s*)"[^"]*"'
    new_text, n = re.subn(pattern, rf'\1"{value}"', text, count=1)
    if n != 1:
        raise RuntimeError(
            f"{path}: expected exactly 1 line matching attribute {field!r}, got {n}. "
            "Check default.nix uses the same attribute name as update.json."
        )
    path.write_text(new_text)


def _current_version(text: str) -> str:
    m = re.search(r'version\s*=\s*"([^"]+)"', text)
    return m.group(1) if m else "unknown"


# ---------------------------------------------------------------------------
# Source type handlers
# Each receives (meta, pkg_dir, status_cb, current_version) and returns
# (new_version, url, field_updates).  current_version is pre-read by
# update_package so handlers never need to re-read default.nix themselves.
# ---------------------------------------------------------------------------


def _handle_npm(
    meta: dict, pkg_dir: Path, status: StatusCb, current_version: str
) -> tuple[str, str, dict]:
    """npm package: fetch latest, compute src hash + npm deps hash."""
    status("fetching latest version from npm")
    data = _fetch_json(f"https://registry.npmjs.org/{meta['package']}/latest")
    new_version = data["version"]
    tarball_url = data["dist"]["tarball"]

    status("hashing tarball")
    src_hash = _nix_sri(tarball_url)

    status("downloading tarball")
    with urllib.request.urlopen(tarball_url, timeout=30, context=_SSL) as r:
        raw = r.read()

    with tempfile.TemporaryDirectory() as tmp:
        tgz = Path(tmp) / "pkg.tgz"
        tgz.write_bytes(raw)
        with tarfile.open(tgz) as tf:
            tf.extractall(tmp)
        pkg_json = Path(tmp) / "package" / "package.json"
        status("generating package-lock.json")
        subprocess.run(
            ["npm", "install", "--package-lock-only", "--ignore-scripts"],
            cwd=pkg_json.parent,
            capture_output=True,
            check=True,
        )
        new_lock = pkg_json.parent / "package-lock.json"
        dest_lock = pkg_dir / meta["lock_file"]
        dest_lock.write_text(new_lock.read_text())
        status("hashing npm deps")
        deps_hash = _npm_deps_hash(dest_lock)

    return (
        new_version,
        tarball_url,
        {
            # Keep fetchurl in sync with npm `dist.tarball` (version bumps alone miss this).
            "url": tarball_url,
            meta["hash_field"]: src_hash,
            meta["npm_deps_hash_field"]: deps_hash,
        },
    )


def _handle_github_release(
    meta: dict, pkg_dir: Path, status: StatusCb, current_version: str
) -> tuple[str, str, dict]:
    """GitHub release: fetch latest tag, compute asset hash."""
    status("fetching latest GitHub release")
    data = _fetch_json(f"https://api.github.com/repos/{meta['repo']}/releases/latest")
    new_version = data["tag_name"].lstrip("v")
    asset = meta["asset"].format(version=new_version)
    url = f"https://github.com/{meta['repo']}/releases/download/v{new_version}/{asset}"

    status("hashing release asset")
    src_hash = _nix_sri(url, unpack=meta.get("unpack", False))

    return new_version, url, {meta["hash_field"]: src_hash}


_GIT_SSH_RESOLVED = re.compile(
    r"^git\+ssh://git@github\.com/(?P<owner>[^/]+)/(?P<repo>[^/]+?)\.git#(?P<commit>[a-fA-F0-9]+)$"
)


def _github_latest_tag(owner: str, repo: str) -> tuple[str, str]:
    """Return (tag_name, version for default.nix `version =` field)."""
    url = f"https://api.github.com/repos/{owner}/{repo}/releases/latest"
    try:
        data = _fetch_json(url)
        tag = data["tag_name"]
    except urllib.error.HTTPError as e:
        if e.code != 404:
            raise
        tags = _fetch_json(f"https://api.github.com/repos/{owner}/{repo}/tags")
        if not tags:
            raise RuntimeError(f"No releases or tags for {owner}/{repo}") from e
        tag = tags[0]["name"]
    version = tag.removeprefix("v") if tag.startswith("v") else tag
    return tag, version


def _nix_prefetch_github_hash(owner: str, repo: str, rev: str) -> str:
    proc = subprocess.run(
        ["nix-prefetch-github", owner, repo, "--rev", rev],
        capture_output=True,
        text=True,
        check=True,
    )
    return json.loads(proc.stdout)["hash"]


def _npm_integrity_sha512_from_url(url: str) -> str:
    req = urllib.request.Request(url, headers={"Accept": "application/octet-stream"})
    with urllib.request.urlopen(req, timeout=60, context=_SSL) as r:
        data = r.read()
    digest = hashlib.sha512(data).digest()
    return "sha512-" + base64.b64encode(digest).decode()


def _find_github_archive_root(tmp: Path, repo_name: str, tag: str) -> Path:
    safe = tag.removeprefix("v") if tag.startswith("v") else tag
    for name in (f"{repo_name}-{tag}", f"{repo_name}-{safe}"):
        p = tmp / name
        if p.is_dir():
            return p
    subs = [p for p in tmp.iterdir() if p.is_dir()]
    if len(subs) == 1:
        return subs[0]
    raise RuntimeError(
        f"Could not find extracted source root under {tmp} for {repo_name}@{tag}"
    )


def _patch_lock_git_ssh(lock: dict) -> None:
    """Rewrite git+ssh resolved entries to https tarballs + integrity (for Nix npm prefetch)."""
    packages = lock.get("packages")
    if not isinstance(packages, dict):
        return

    for _key, entry in packages.items():
        if not isinstance(entry, dict):
            continue
        resolved = entry.get("resolved")
        if not isinstance(resolved, str):
            continue
        m = _GIT_SSH_RESOLVED.match(resolved)
        if not m:
            continue
        owner, repo, commit = m.group("owner"), m.group("repo"), m.group("commit")
        tarball = f"https://github.com/{owner}/{repo}/archive/{commit}.tar.gz"
        entry["resolved"] = tarball
        entry["integrity"] = _npm_integrity_sha512_from_url(tarball)

    root = packages.get("")
    if isinstance(root, dict):
        deps = root.get("dependencies")
        if isinstance(deps, dict):
            for name, spec in list(deps.items()):
                if isinstance(spec, str) and spec.startswith("github:"):
                    mod = packages.get(f"node_modules/{name}")
                    if isinstance(mod, dict):
                        res = mod.get("resolved")
                        if isinstance(res, str) and res.startswith(
                            "https://github.com"
                        ):
                            deps[name] = res


def _handle_github_npm(
    meta: dict, pkg_dir: Path, status: StatusCb, current_version: str
) -> tuple[str, str, dict]:
    """GitHub release/tag + fetchFromGitHub + buildNpmPackage: refresh lock + hashes."""
    owner, repo_name = meta["repo"].split("/", 1)

    status("fetching latest GitHub tag")
    tag, new_version = _github_latest_tag(owner, repo_name)
    if new_version == current_version:
        return new_version, "", {}

    quoted_tag = urllib.parse.quote(tag, safe="")
    archive_url = (
        f"https://github.com/{owner}/{repo_name}/archive/refs/tags/{quoted_tag}.tar.gz"
    )

    with tempfile.TemporaryDirectory() as tmp_s:
        tmp = Path(tmp_s)
        arc = tmp / "src.tar.gz"
        req = urllib.request.Request(
            archive_url, headers={"Accept": "application/octet-stream"}
        )
        status("downloading source archive")
        with urllib.request.urlopen(req, timeout=120, context=_SSL) as r:
            arc.write_bytes(r.read())
        status("extracting archive")
        with tarfile.open(arc) as tf:
            if sys.version_info >= (3, 12):
                tf.extractall(tmp, filter="data")
            else:
                tf.extractall(tmp)
        src_root = _find_github_archive_root(tmp, repo_name, tag)
        upstream_lock = src_root / "package-lock.json"
        if not upstream_lock.is_file():
            raise RuntimeError(f"No package-lock.json in {owner}/{repo_name}@{tag}")

        lock = json.loads(upstream_lock.read_text())
        if meta.get("patch_git_ssh_lock"):
            status("patching git+ssh lockfile entries")
            _patch_lock_git_ssh(lock)
        dest_lock = pkg_dir / meta["lock_file"]
        dest_lock.write_text(json.dumps(lock, indent=2) + "\n")

        status("hashing npm deps")
        deps_hash = _npm_deps_hash(dest_lock)

    status("prefetching GitHub source hash")
    src_hash = _nix_prefetch_github_hash(owner, repo_name, tag)

    return (
        new_version,
        archive_url,
        {
            meta.get("rev_field", "rev"): tag,
            meta["hash_field"]: src_hash,
            meta["npm_deps_hash_field"]: deps_hash,
        },
    )


def _handle_github_tag(
    meta: dict, pkg_dir: Path, status: StatusCb, current_version: str
) -> tuple[str, str, dict]:
    """GitHub tag + fetchFromGitHub: bump `version` and refresh `hash_field` via nix-prefetch-github."""
    owner, repo_name = meta["repo"].split("/", 1)

    status("fetching latest GitHub tag")
    tag, new_version = _github_latest_tag(owner, repo_name)

    quoted_tag = urllib.parse.quote(tag, safe="")
    archive_url = (
        f"https://github.com/{owner}/{repo_name}/archive/refs/tags/{quoted_tag}.tar.gz"
    )

    status("prefetching GitHub source hash")
    src_hash = _nix_prefetch_github_hash(owner, repo_name, tag)

    return new_version, archive_url, {meta["hash_field"]: src_hash}


_HANDLERS = {
    "npm": _handle_npm,
    "github_release": _handle_github_release,
    "github_tag": _handle_github_tag,
    "github_npm": _handle_github_npm,
}


# ---------------------------------------------------------------------------
# Core update logic
# ---------------------------------------------------------------------------


def update_package(
    pkg_dir: Path,
    status: StatusCb = _noop,
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

    if not force and cooldown_s > 0:
        last = _read_last_checked(pkg_dir)
        if last is not None and (time.time() - last) < cooldown_s:
            status(
                f"skipped (cooldown {_cooldown_remaining_human(last, cooldown_s)})"
            )
            return old_version, old_version, False, False, True

    meta = json.loads((pkg_dir / "update.json").read_text())
    handler = _HANDLERS[meta["type"]]
    new_version, _url, field_updates = handler(meta, pkg_dir, status, old_version)

    version_changed = new_version != old_version
    # Detect hash drift: field present in nix file but value differs from computed
    fields_changed = any(
        not re.search(
            rf'(?m)^[ \t]*{re.escape(field)}\s*=\s*"{re.escape(value)}"',
            nix_text,
        )
        for field, value in field_updates.items()
    )

    if not version_changed and not fields_changed:
        _write_last_checked(pkg_dir)
        return old_version, new_version, False, False, False

    status("writing updated default.nix")
    if version_changed:
        _replace_attr_once(nix_file, "version", new_version)
    for field, value in field_updates.items():
        _replace_attr_once(nix_file, field, value)

    _write_last_checked(pkg_dir)
    return old_version, new_version, version_changed, fields_changed, False


def discover_packages(flake_root: Path) -> list[Path]:
    return sorted(p.parent for p in (flake_root / "packages").glob("*/update.json"))


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------


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
                try:
                    old, new, version_changed, fields_changed, cooldown_skipped = (
                        future.result()
                    )
                    if cooldown_skipped:
                        progress.update(
                            tid,
                            icon="[dim]~[/]",
                            description=f"[dim]{pkg_dir.name}[/]",
                            step="[dim]cooldown (1h)[/]",
                            completed=1,
                        )
                    elif version_changed:
                        progress.update(
                            tid,
                            icon="[green]✓[/]",
                            description=f"[bold]{pkg_dir.name}[/]",
                            step=f"{old} → [green]{new}[/]",
                            completed=1,
                        )
                        changed.append(pkg_dir.name)
                    elif fields_changed:
                        progress.update(
                            tid,
                            icon="[yellow]✓[/]",
                            description=f"[bold]{pkg_dir.name}[/]",
                            step=f"[yellow]hashes updated[/] ({new})",
                            completed=1,
                        )
                        changed.append(pkg_dir.name)
                    else:
                        progress.update(
                            tid,
                            icon="[dim]–[/]",
                            description=f"[dim]{pkg_dir.name}[/]",
                            step=f"[dim]already at {new}[/]",
                            completed=1,
                        )
                except Exception as e:
                    progress.update(
                        tid,
                        icon="[red]✗[/]",
                        description=f"[red]{pkg_dir.name}[/]",
                        step=f"[red]{e}[/]",
                        completed=1,
                    )
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
