"""Update custom flake packages by reading update.json metadata from each package dir."""

import json
import re
import ssl
import subprocess
import sys
import tarfile
import tempfile
import urllib.request
from pathlib import Path

import certifi


from flake_scripts.lib.common import bad, info, resolve_flake_root

_SSL = ssl.create_default_context(cafile=certifi.where())

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
        capture_output=True, text=True, check=True,
    ).stdout.strip()


def _npm_deps_hash(lock_file: Path) -> str:
    return subprocess.run(
        ["nix", "run", "nixpkgs#prefetch-npm-deps", "--", str(lock_file)],
        capture_output=True, text=True, check=True,
    ).stdout.strip()


def _sub(path: Path, pattern: str, replacement: str) -> None:
    text = path.read_text()
    path.write_text(re.sub(pattern, replacement, text, count=1))


# ---------------------------------------------------------------------------
# Source type handlers — each returns (new_version, updates: dict[field -> value])
# ---------------------------------------------------------------------------

def _handle_npm(meta: dict, pkg_dir: Path) -> tuple[str, str, dict]:
    """npm package: fetch latest, compute src hash + npm deps hash."""
    data = _fetch_json(f"https://registry.npmjs.org/{meta['package']}/latest")
    new_version = data["version"]
    tarball_url = data["dist"]["tarball"]

    src_hash = _nix_sri(tarball_url)

    # Download tarball, generate package-lock.json, compute npmDepsHash
    with urllib.request.urlopen(tarball_url, timeout=30, context=_SSL) as r:
        raw = r.read()
    with tempfile.TemporaryDirectory() as tmp:
        tgz = Path(tmp) / "pkg.tgz"
        tgz.write_bytes(raw)
        with tarfile.open(tgz) as tf:
            tf.extractall(tmp)
        pkg_json = Path(tmp) / "package" / "package.json"
        subprocess.run(
            ["npm", "install", "--package-lock-only", "--ignore-scripts"],
            cwd=pkg_json.parent, capture_output=True, check=True,
        )
        new_lock = pkg_json.parent / "package-lock.json"
        dest_lock = pkg_dir / meta["lock_file"]
        dest_lock.write_text(new_lock.read_text())
        deps_hash = _npm_deps_hash(dest_lock)

    return new_version, tarball_url, {
        meta["hash_field"]: src_hash,
        meta["npm_deps_hash_field"]: deps_hash,
    }


def _handle_github_release(meta: dict, pkg_dir: Path) -> tuple[str, str, dict]:
    """GitHub release: fetch latest tag, compute asset hash."""
    data = _fetch_json(f"https://api.github.com/repos/{meta['repo']}/releases/latest")
    new_version = data["tag_name"].lstrip("v")
    asset = meta["asset"].format(version=new_version)
    url = f"https://github.com/{meta['repo']}/releases/download/v{new_version}/{asset}"

    src_hash = _nix_sri(url, unpack=meta.get("unpack", False))

    return new_version, url, {meta["hash_field"]: src_hash}


_HANDLERS = {
    "npm": _handle_npm,
    "github_release": _handle_github_release,
}


# ---------------------------------------------------------------------------
# Core update logic
# ---------------------------------------------------------------------------

def _current_version(nix_file: Path) -> str:
    m = re.search(r'version\s*=\s*"([^"]+)"', nix_file.read_text())
    return m.group(1) if m else "unknown"


def update_package(pkg_dir: Path) -> tuple[str, str, bool]:
    """Update a single package. Returns (old_version, new_version, changed)."""
    meta_file = pkg_dir / "update.json"
    meta = json.loads(meta_file.read_text())
    nix_file = pkg_dir / "default.nix"

    old_version = _current_version(nix_file)
    handler = _HANDLERS[meta["type"]]
    new_version, _url, field_updates = handler(meta, pkg_dir)

    if old_version == new_version:
        return old_version, new_version, False

    _sub(nix_file, r'version\s*=\s*"[^"]+"', f'version = "{new_version}"')
    for field, value in field_updates.items():
        _sub(nix_file, rf'{re.escape(field)}\s*=\s*"[^"]+"', f'{field} = "{value}"')

    return old_version, new_version, True


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
    ap.add_argument("packages", nargs="*", choices=all_names, metavar="PACKAGE",
                    help=f"Packages to update (default: all). Available: {', '.join(all_names)}")
    parsed = ap.parse_args(args)

    targets = [flake_root / "packages" / n for n in parsed.packages] if parsed.packages else all_pkgs

    changed, failed = [], False
    for pkg_dir in targets:
        try:
            old, new, did_change = update_package(pkg_dir)
            if did_change:
                info(f"[green]✓[/] {pkg_dir.name}: {old} → {new}")
                changed.append(pkg_dir.name)
            else:
                info(f"[dim]–[/] {pkg_dir.name}: already at {new}")
        except Exception as e:
            bad(f"[red]✗[/] {pkg_dir.name}: {e}")
            failed = True

    if changed:
        info(f"\n[bold]Updated {len(changed)} package(s).[/] Run [cyan]just fmt && just switch[/] to apply.")
    elif not failed:
        info("\n[dim]All packages up to date.")

    if failed:
        sys.exit(1)


if __name__ == "__main__":
    main()
