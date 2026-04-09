"""Shared path helpers and Rich-backed CLI output for flake_scripts."""

from __future__ import annotations

import os
from datetime import datetime
from pathlib import Path

from rich import box
from rich.console import Console
from rich.rule import Rule
from rich.table import Table
from rich.theme import Theme

from flake_scripts.lib.palette import rich_theme_styles

_THEME = Theme(rich_theme_styles())

console = Console(theme=_THEME)
console_err = Console(theme=_THEME, stderr=True)


def resolve_flake_root(explicit: Path | None = None, *, anchor: Path | None = None) -> Path:
    """Resolve flake root: explicit arg, $FLAKE, cwd walk-up, optional anchor file walk-up, then ~/.dotfiles/flake."""
    if explicit is not None:
        return explicit.expanduser().resolve()
    env = os.environ.get("FLAKE")
    if env:
        return Path(env).resolve()
    cwd = Path.cwd()
    for p in [cwd, *cwd.parents]:
        if (p / "flake.nix").is_file():
            return p.resolve()
    if anchor is not None:
        ap = Path(anchor).resolve()
        for p in [ap, *ap.parents]:
            if (p / "flake.nix").is_file():
                return p.resolve()
    return (Path.home() / ".dotfiles" / "flake").resolve()


def host_is_nixos() -> bool:
    """True when this machine is NixOS Linux (/etc/NIXOS or ID=nixos in /etc/os-release)."""
    import sys
    if sys.platform != "linux":
        return False
    if os.path.isfile("/etc/NIXOS"):
        return True
    try:
        with open("/etc/os-release", encoding="utf-8") as f:
            return any(line.strip() == "ID=nixos" for line in f)
    except OSError:
        return False


def xdg_config_home() -> Path:
    xdg = os.environ.get("XDG_CONFIG_HOME")
    if xdg:
        return Path(xdg).expanduser().resolve()
    return (Path.home() / ".config").resolve()


def is_path_under(path: Path, parent: Path) -> bool:
    try:
        path.resolve().relative_to(parent.resolve())
        return True
    except ValueError:
        return False


def format_mtime(path: Path) -> str:
    try:
        st = path.stat()
        return datetime.fromtimestamp(st.st_mtime).isoformat(sep=" ", timespec="seconds")
    except OSError:
        return "(unknown)"


def rule(title: str, *, stderr: bool = False) -> None:
    (console_err if stderr else console).print(Rule(title, style="title"))


def ok(msg: str, *, stderr: bool = False) -> None:
    (console_err if stderr else console).print(f"[ok]✓[/] {msg}")


def bad(msg: str, *, stderr: bool = False) -> None:
    (console_err if stderr else console).print(f"[bad]✗[/] {msg}")


def warn(msg: str, *, stderr: bool = False) -> None:
    (console_err if stderr else console).print(f"[warn]⚠[/] {msg}")


def info(msg: str, *, stderr: bool = False) -> None:
    (console_err if stderr else console).print(f"[info]▪[/] {msg}")


def dim(msg: str, *, stderr: bool = False) -> None:
    (console_err if stderr else console).print(f"[dim]{msg}[/]")


def dim_lines(*lines: str, stderr: bool = True) -> None:
    c = console_err if stderr else console
    for line in lines:
        c.print(f"[dim]{line}[/]")


def print_dir_symlink_audit(config_dir: Path) -> None:
    """Print a compact table of entries under config_dir (symlink vs file)."""
    dim(f"Checking {config_dir}/")
    if not config_dir.is_dir():
        bad(f"{config_dir} directory does not exist")
        return
    entries = sorted(config_dir.iterdir(), key=lambda p: p.name)
    if not entries:
        dim("  (empty directory)")
        return
    table = Table(show_header=True, box=box.SIMPLE, pad_edge=False)
    table.add_column("Name", style="tbl_name", header_style="tbl_header")
    table.add_column("Status", header_style="tbl_header")
    table.add_column("Detail", style="tbl_detail", header_style="tbl_header")
    for path in entries:
        name = path.name
        if path.is_symlink():
            target = path.resolve()
            if target.is_file():
                table.add_row(name, "[ok]symlink[/]", str(target))
            else:
                table.add_row(name, "[bad]symlink[/]", f"{target} [bad](missing target)[/]")
        elif path.is_file():
            table.add_row(name, "[bad]regular file[/]", "expected symlink")
        else:
            table.add_row(name, "[dim]other[/]", "")
    console.print(table)
