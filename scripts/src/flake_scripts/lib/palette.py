"""Birds of Paradise hex values — mirror lib/theme-palette.nix.

Update this file when the Nix palette changes so CLI tools stay on-brand.
"""

from __future__ import annotations

# Keys match theme.nix attribute names (underscores).
PALETTE: dict[str, str] = {
    "bg_primary": "#372725",
    "bg_secondary": "#2e201f",
    "bg_tertiary": "#5B413D",
    "text_primary": "#E6E1C4",
    "text_secondary": "#feffff",
    "text_tertiary": "#DDDDDD",
    "accent_blue": "#6b98bb",
    "accent_yellow": "#EFCB43",
    "accent_red": "#A40042",
    "ansi_black": "#6a4d32",
    "ansi_blue": "#6b98bb",
    "ansi_cyan": "#85b4bb",
    "ansi_green": "#6ba18a",
    "ansi_magenta": "#bb94b4",
    "ansi_red": "#cb4131",
    "ansi_white": "#E6E1C4",
    "ansi_yellow": "#eeac36",
    "ansi_bright_black": "#ac7f5c",
    "ansi_bright_blue": "#c4dbf0",
    "ansi_bright_cyan": "#a2d7de",
    "ansi_bright_green": "#a3ddc6",
    "ansi_bright_magenta": "#dab0d4",
    "ansi_bright_red": "#ee5d32",
    "ansi_bright_white": "#feffff",
    "ansi_bright_yellow": "#d8d762",
}


def _p(key: str) -> str:
    return PALETTE[key]


def rich_theme_styles() -> dict[str, str]:
    """Rich Theme() entries for flake_scripts CLI output."""
    return {
        "default": _p("text_primary"),
        "ok": f"bold {_p('ansi_bright_green')}",
        "bad": f"bold {_p('ansi_bright_red')}",
        "warn": f"bold {_p('ansi_bright_yellow')}",
        "info": f"bold {_p('ansi_bright_cyan')}",
        "dim": _p("ansi_bright_black"),
        "title": f"bold {_p('accent_blue')}",
        "tbl_name": f"bold {_p('text_primary')}",
        "tbl_detail": _p("ansi_bright_black"),
        "tbl_header": f"bold {_p('accent_yellow')}",
    }
