#!/usr/bin/env python3
"""Extract packages from flake Nix files and check nixpkgs availability per platform."""
import re
import subprocess
import sys
from pathlib import Path

from flake_scripts.lib.common import resolve_flake_root

ROOT = resolve_flake_root(anchor=Path(__file__))

KEYWORDS = {
    "with", "pkgs", "lib", "config", "true", "false", "null", "let", "in", "rec",
    "inherit", "import", "if", "then", "else", "assert", "or", "and", "not",
    "home", "environment", "systemPackages", "packages", "fonts",
    "enable", "settings", "programs", "services", "ps",
}

MARKERS = [
    "home.packages = with pkgs; [",
    "environment.systemPackages = with pkgs; [",
    "fonts.packages = with pkgs; [",
]


def extract_list_content(content: str, marker: str) -> str:
    i = content.find(marker)
    if i < 0:
        return ""
    start = i + len(marker)
    depth = 1
    j = start
    while j < len(content) and depth:
        c = content[j]
        if c == "[":
            depth += 1
        elif c == "]":
            depth -= 1
        j += 1
    return content[start : j - 1] if depth == 0 else ""


def names_from_list(text: str) -> list[str]:
    out: list[str] = []
    for line in text.split("\n"):
        line = line.split("#")[0].strip()
        if not line:
            continue
        for tok in line.split():
            pkg = re.sub(r"^[;,\[\]]+|[;,\[\]]+$", "", tok).strip()
            if len(pkg) <= 2 or pkg in KEYWORDS or pkg.startswith("."):
                continue
            if any(c in pkg for c in "={}"):
                continue
            out.append(pkg)
    seen: set[str] = set()
    return [x for x in out if not (x in seen or seen.add(x))]


def extract_file(path: Path) -> list[str]:
    try:
        content = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return []
    allp: list[str] = []
    for marker in MARKERS:
        block = extract_list_content(content, marker)
        if block:
            allp.extend(names_from_list(block))
    seen: set[str] = set()
    return [x for x in allp if not (x in seen or seen.add(x))]


def cat_for_path(p: str) -> str:
    if "/shared/" in p or p.endswith("/shared") or "/home/shared" in p:
        return "shared"
    if "nixos" in p:
        return "nixos"
    if "darwin" in p:
        return "darwin"
    return "shared"


def scan_dirs(rel_parts: list[str]) -> dict[str, list[str]]:
    pkgs: dict[str, list[str]] = {"shared": [], "nixos": [], "darwin": []}
    for rd in rel_parts:
        d = ROOT / rd
        if not d.is_dir():
            continue
        for f in d.rglob("*.nix"):
            s = str(f)
            c = cat_for_path(s)
            for pkg in extract_file(f):
                if pkg not in pkgs[c]:
                    pkgs[c].append(pkg)
    return pkgs


def main() -> int:
    home = scan_dirs(["home/shared", "home/nixos", "home/darwin"])
    sys_ = scan_dirs(["modules/shared", "modules/nixos", "modules/darwin"])

    categories = [
        ("Home Packages (Shared)", home["shared"], ["x86_64-linux", "aarch64-darwin"]),
        ("Home Packages (NixOS)", home["nixos"], ["x86_64-linux"]),
        ("Home Packages (Darwin)", home["darwin"], ["aarch64-darwin"]),
        ("System Packages (Shared)", sys_["shared"], ["x86_64-linux", "aarch64-darwin"]),
        ("System Packages (NixOS)", sys_["nixos"], ["x86_64-linux"]),
        ("System Packages (Darwin)", sys_["darwin"], ["aarch64-darwin"]),
    ]

    print("Package categories:")
    total_u = len({p for _, pkgs, _ in categories for p in pkgs})
    for name, pkgs, plats in categories:
        print(f"  {name}: {len(pkgs)} packages — {', '.join(plats)}")
    print(f"\nTotal unique packages: {total_u}\n")

    results: list[dict] = []
    for cat_name, packages, platforms in categories:
        for plat in platforms:
            available: list[str] = []
            unfree: list[str] = []
            unavailable: list[str] = []
            print(f"Checking {len(packages)} packages on {plat} ({cat_name})...")
            r = subprocess.run(
                ["nix", "flake", "metadata", "github:NixOS/nixpkgs", "--system", plat],
                capture_output=True,
                text=True,
            )
            if r.returncode != 0:
                print(f"  nixpkgs not available for {plat}")
                unavailable.extend(packages)
                results.append(
                    {
                        "category": cat_name,
                        "platform": plat,
                        "available": [],
                        "unfree": [],
                        "unavailable": list(packages),
                    }
                )
                continue

            for pkg in packages:
                if ".withPackages" in pkg or pkg == "ps":
                    continue
                er = subprocess.run(
                    [
                        "nix",
                        "eval",
                        "--system",
                        plat,
                        "--json",
                        f"github:NixOS/nixpkgs#{pkg}",
                    ],
                    capture_output=True,
                    text=True,
                )
                if er.returncode == 0:
                    available.append(pkg)
                else:
                    err = (er.stderr or "") + (er.stdout or "")
                    if "unfree" in err.lower():
                        unfree.append(pkg)
                    else:
                        unavailable.append(pkg)

            na, nf, nu = len(available), len(unfree), len(unavailable)
            print(f"  Available: {na}, Unfree: {nf}, Unavailable: {nu}")
            if unfree:
                print(f"    Unfree (allowUnfree): {', '.join(unfree[:10])}{'...' if len(unfree) > 10 else ''}")
            if unavailable:
                show = unavailable[:5]
                print(f"    Missing: {', '.join(show)}")
                if len(unavailable) > 5:
                    print(f"    ... and {len(unavailable) - 5} more")

            results.append(
                {
                    "category": cat_name,
                    "platform": plat,
                    "available": available,
                    "unfree": unfree,
                    "unavailable": unavailable,
                }
            )

    print("\n=== Summary ===")
    for row in results:
        tot = len(row["available"]) + len(row["unfree"]) + len(row["unavailable"])
        ok = len(row["available"]) + len(row["unfree"])
        issues = ""
        if row["unfree"]:
            issues += f" unfree:{len(row['unfree'])}"
        if row["unavailable"]:
            issues += f" missing:{len(row['unavailable'])}"
        print(f"  {row['category']} / {row['platform']}: {ok}/{tot} ok{issues}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
